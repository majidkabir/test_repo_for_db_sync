SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Stored Procedure: isp_TPB_Adjustment_UA                              */      
/* Creation Date:                                                       */      
/* Copyright: IDS                                                       */      
/* Written by:                                                          */      
/*                                                                      */      
/* Purpose: TPB billing for UA Adjustment Transaction                   */      
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
/* 08-Jun-18    TLTING01  1.2   bug fix                                 */     
/************************************************************************/  



CREATE PROC [dbo].[isp_TPB_Adjustment_UA]
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
      ',''A'' ' +                      --  A = ACTIVITIES
      ',''ADJUSTMENT'' ' +
      ',@c_COUNTRYISO ' +
      ',UPPER(RTRIM(ADJUSTMENT.Facility)) ' +
      ',ADJUSTMENT.AddDate ' +
      ',ADJUSTMENT.AddWho ' +
      ',ADJUSTMENT.EditDate ' +
      ',ADJUSTMENT.EditWho ' +
      ',''WMS'' ' +
      ',''9'' ' +
      ',''J'' ' +
      ',RTRIM(ADJUSTMENT.AdjustmentType) ' +
      ',RTRIM(ADJUSTMENT.AdjustmentKey) ' +
      ',RTRIM(AD.AdjustmentLineNumber) ' +
      ',UPPER(RTRIM(ADJUSTMENT.StorerKey)) ' +
      ',cast(RTRIM(ADJUSTMENT.Remarks) as Nvarchar(100)) ' +     -- tlting        
      ',UPPER(RTRIM(AD.SKU)) '+
      ',AD.Qty ' +
      ',RTRIM(AD.UOM) ' +
      ','''' ' +                   --GrossWgt
      ','''' ' +                   --Cube
      ',RTRIM(AD.Lottable01) ' +
      ',RTRIM(AD.Lottable02) ' +
      ',RTRIM(AD.Lottable03) ' +
      ',AD.Lottable04 ' +
      ',AD.Lottable05 ' +
      ',RTRIM(AD.Lottable06) ' +
      ',RTRIM(AD.Lottable07) ' +
      ',RTRIM(AD.Lottable08) ' +
      ',RTRIM(AD.Lottable09) ' +
      ',RTRIM(AD.Lottable10) ' +
      ',RTRIM(AD.Lottable11) ' +
      ',RTRIM(AD.Lottable12) ' +
      ',AD.Lottable13 ' +
      ',AD.Lottable14 ' +
      ',AD.Lottable15 ' +
      ',RTRIM(ADJUSTMENT.UserDefine01) ' +
      ',RTRIM(ADJUSTMENT.UserDefine02) ' +
      ',RTRIM(ADJUSTMENT.UserDefine03) ' +
      ',RTRIM(ADJUSTMENT.UserDefine04) ' +
      ',RTRIM(ADJUSTMENT.UserDefine05) ' +
      ',RTRIM(ADJUSTMENT.UserDefine06) ' +
      ',RTRIM(ADJUSTMENT.UserDefine07) ' +
      ',RTRIM(ADJUSTMENT.UserDefine08) ' +
      ',RTRIM(ADJUSTMENT.UserDefine09) ' +
      ',RTRIM(ADJUSTMENT.UserDefine10) ' +
      ',RTRIM(AD.UserDefine01) ' +
      ',RTRIM(AD.UserDefine02) ' +
      ',RTRIM(AD.UserDefine03) ' +
      ',RTRIM(AD.UserDefine04) ' +
      ',RTRIM(AD.UserDefine05) ' +
      ',RTRIM(AD.UserDefine06) ' +
      ',RTRIM(AD.UserDefine07) ' +
      ',RTRIM(AD.UserDefine08) ' +
      ',RTRIM(AD.UserDefine09) ' +
      ',RTRIM(AD.UserDefine10) ' +
       ','''' ' +                          --FromLoc
       ','''' ' +                          --ToLoc
       ','''' ' +                          -- PICKDETAIL.FromLot  -- invalid 'FromLot' column name in ' PICKDETAIL' table
       ','''' ' +                          --ToLot
      ',RTRIM(SKU.DESCR) ' +
      ',RTRIM(SKU.SUSR3) ' +
      ',ADJUSTMENT.EditDate ' 

      SET @c_SQLStatement = @c_SQLStatement +
              N'FROM dbo.ADJUSTMENT (NOLOCK) ' +
              'JOIN dbo.ADJUSTMENTDETAIL AD (NOLOCK) ON AD.AdjustmentKey = ADJUSTMENT.AdjustmentKey ' +
              'JOIN dbo.SKU (NOLOCK) ON SKU.StorerKey = AD.StorerKey AND SKU.SKU = AD.Sku ' +
              'JOIN dbo.FACILITY (NOLOCK) ON FACILITY.Facility = ADJUSTMENT.Facility ' +
              'JOIN dbo.LOTATTRIBUTE (NOLOCK) ON LOTATTRIBUTE.Lot = AD.Lot ' +
              'WHERE ADJUSTMENT.FinalizedFlag =''Y'' ' +
              'AND ADJUSTMENT.EditDate between @d_Fromdate and @d_Todate ' +
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
     , Config_ID
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
     ,DOC_SUB_TYPE
     ,DOCUMENT_ID
     ,DOCUMENT_LINE_NO
     ,CLIENT_ID
     ,OTHER_REFERENCE_1
     ,SKU_ID
     ,BILLABLE_QUANTITY
     ,QTY_UOM
     ,BILLABLE_WEIGHT
     ,BILLABLE_CBM
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
     ,LOC
     ,TO_LOC
     ,LOT
     ,TO_LOT
     ,SKU_DESCRIPTION
     ,SKU_SUSR3
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