SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Stored Procedure: isp_TPB_IQC_Generic                                */      
/* Creation Date:                                                       */      
/* Copyright: IDS                                                       */      
/* Written by:                                                          */      
/*                                                                      */      
/* Purpose: TPB billing for Generic InventoryQC Transaction             */      
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



CREATE PROC [dbo].[isp_TPB_IQC_Generic]
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
      ',''A'' ' +             --  A = ACTIVITIES
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
      ',UPPER(RTRIM(IQC.Storerkey)) ' +
      ',UPPER(RTRIM(IQCD.SKU)) ' +
      ',IQCD.QTY ' +
      ',RTRIM(IQCD.UOM) ' +
      ',RTRIM(IQC.UserDefine01) ' +
      ',RTRIM(IQC.UserDefine02) ' +
      ',RTRIM(IQC.UserDefine03) ' +
      ',RTRIM(IQC.UserDefine04) ' +
      ',RTRIM(IQC.UserDefine05) ' +
      ',RTRIM(IQC.UserDefine06) ' +
      ',RTRIM(IQC.UserDefine07) ' +
      ',RTRIM(IQC.UserDefine08) ' +
      ',RTRIM(IQC.UserDefine09) ' +
      ',RTRIM(IQC.UserDefine10) ' +
      ',RTRIM(IQCD.UserDefine01) ' +
      ',RTRIM(IQCD.UserDefine02) ' +
      ',RTRIM(IQCD.UserDefine03) ' +
      ',RTRIM(IQCD.UserDefine04) ' +
      ',RTRIM(IQCD.UserDefine05) ' +
      ',RTRIM(IQCD.UserDefine06) ' +
      ',RTRIM(IQCD.UserDefine07) ' +
      ',RTRIM(IQCD.UserDefine08) ' +
      ',RTRIM(IQCD.UserDefine09) ' +
      ',RTRIM(IQCD.UserDefine10) ' +
      ',RTRIM(IQCD.FromLoc) ' +
      ',RTRIM(IQCD.ToLoc) ' +
      ',RTRIM(IQCD.FromLot) ' +
--      ',IQCD.ToLot ' +              --invalid 'ToLot' column name in IQCD table
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
      ',IQC.EditDate ' 

      SET @c_SQLStatement = @c_SQLStatement +
         N'FROM dbo.InventoryQC IQC (NOLOCK) ' +
         'JOIN dbo.InventoryQCDETAIL IQCD (NOLOCK) ON IQCD.QC_Key = IQC.QC_Key ' +
         'JOIN dbo.Facility F (NOLOCK) ON F.Facility = IQC.To_facility ' +  -- ??
         'JOIN dbo.LOTATTRIBUTE L (NOLOCK) ON L.lot = IQCD.FromLot ' +
         'WHERE IQC.FinalizeFlag = ''Y'' ' +
         'AND IQC.EditDate between @d_Fromdate and @d_Todate ' +
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
     ,CLIENT_ID
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
     ,LOC
     ,TO_LOC
     ,LOT
--     ,TO_LOT
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