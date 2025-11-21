SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_TPB_Transfer_Carters                           */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: TPB billing for CHN Carter Transfer Transaction             */
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

CREATE PROC [dbo].[isp_TPB_Transfer_Carters_Archive]
   @n_WMS_BatchNo BIGINT,
   @n_TPB_Key     BIGINT,
   @d_BillDate    DATE,
   @n_RecCOUNT    INT = 0 OUTPUT,
   @n_debug       INT = 0,
   @c_ArchiveDB   NVARCHAR(30) = ''
AS
BEGIN
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET NOCOUNT ON

   DECLARE @d_Todate     DATETIME
   DECLARE @d_Fromdate   DATETIME
   DECLARE @c_COUNTRYISO NVARCHAR(5)

   DECLARE @c_SQLStatement NVARCHAR(MAX),
           @c_SQLParm      NVARCHAR(4000),
           @c_SQLCondition NVARCHAR(4000)

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
      ',''A'' ' +            --  A = ACTIVITIES
      ',''TRANSFER'' ' +
      ',@c_COUNTRYISO ' +
      ',UPPER(RTRIM(TRANSFER.Facility)) ' +
      ',UPPER(RTRIM(TRANSFER.ToFacility)) ' +
      ',TRANSFER.AddDate ' +
      ',TRANSFER.AddWho ' +
      ',TRANSFER.EditDate ' +
      ',TRANSFER.EditWho ' +
      ',''WMS'' ' +
      ',TRANSFER.Status ' +
      ',''TT'' ' +        -- TT = Transfer To
      ',RTRIM(TRANSFER.[Type]) ' +
      ',RTRIM(TRANSFER.ReasonCode) ' +        -- invalid 'Reason' column name in the 'TRANSFER' table, change to 'ReasonCode'
      ',RTRIM(TRANSFER.TransferKey) ' +
      ',RTRIM(TRANSFERDETAIL.TransferLineNumber) ' +    -- invalid 'TransferLineNumber ' in 'TRANSFER' table, in 'TRANSFERDETAIL' table have
      ',UPPER(RTRIM(TRANSFER.FromStorerKey)) ' +
      ',UPPER(RTRIM(TRANSFER.ToStorerKey)) ' +
      ',TRANSFER.EffectiveDate ' +
      ',UPPER(RTRIM(TRANSFERDETAIL.FromSKU)) ' +
      ',TRANSFERDETAIL.FromQty ' +
      ',RTRIM(TRANSFERDETAIL.FromUOM) ' +
      ',RTRIM(TRANSFERDETAIL.Lottable01) ' +
      ',RTRIM(TRANSFERDETAIL.Lottable02) ' +
      ',RTRIM(TRANSFERDETAIL.Lottable03) ' +
      ',TRANSFERDETAIL.Lottable04 ' +
      ',TRANSFERDETAIL.Lottable05 ' +
      ',RTRIM(TRANSFERDETAIL.Lottable06) ' +
      ',RTRIM(TRANSFERDETAIL.Lottable07) ' +
      ',RTRIM(TRANSFERDETAIL.Lottable08) ' +
      ',RTRIM(TRANSFERDETAIL.Lottable09) ' +
      ',RTRIM(TRANSFERDETAIL.Lottable10) ' +
      ',RTRIM(TRANSFERDETAIL.Lottable11) ' +
      ',RTRIM(TRANSFERDETAIL.Lottable12) ' +
      ',TRANSFERDETAIL.Lottable13 ' +
      ',TRANSFERDETAIL.Lottable14 ' +
      ',TRANSFERDETAIL.Lottable15 ' +
      ',RTRIM([TRANSFER].UserDefine01) ' +
      ',RTRIM([TRANSFER].UserDefine02) ' +
      ',RTRIM([TRANSFER].UserDefine03) ' +
      ',RTRIM([TRANSFER].UserDefine04) ' +
      ',RTRIM([TRANSFER].UserDefine05) ' +
      ',RTRIM([TRANSFER].UserDefine06) ' +
      ',RTRIM([TRANSFER].UserDefine07) ' +
      ',RTRIM([TRANSFER].UserDefine08) ' +
      ',RTRIM([TRANSFER].UserDefine09) ' +
      ',RTRIM([TRANSFER].UserDefine10) ' +
      ',RTRIM(TRANSFERDETAIL.UserDefine01) ' +
      ',RTRIM(TRANSFERDETAIL.UserDefine02) ' +
      ',RTRIM(TRANSFERDETAIL.UserDefine03) ' +
      ',RTRIM(TRANSFERDETAIL.UserDefine04) ' +
      ',RTRIM(TRANSFERDETAIL.UserDefine05) ' +
      ',RTRIM(TRANSFERDETAIL.UserDefine06) ' +
      ',RTRIM(TRANSFERDETAIL.UserDefine07) ' +
      ',RTRIM(TRANSFERDETAIL.UserDefine08) ' +
      ',RTRIM(TRANSFERDETAIL.UserDefine09) ' +
      ',RTRIM(TRANSFERDETAIL.UserDefine10) ' +
      ',RTRIM(TRANSFERDETAIL.FromLoc) ' +
      ',RTRIM(TRANSFERDETAIL.ToLoc) ' +
      ',RTRIM(TRANSFERDETAIL.FromLot) ' +
      ',RTRIM(TRANSFERDETAIL.ToLot) ' +
      ',RTRIM(TRANSFERDETAIL.FromID) ' +
      ',RTRIM(TRANSFERDETAIL.ToId) ' +
      ',RTRIM(TRANSFERDETAIL.ToLottable01) ' +
      ',RTRIM(TRANSFERDETAIL.ToLottable02) ' +
      ',RTRIM(TRANSFERDETAIL.ToLottable03) ' +
      ',TRANSFERDETAIL.ToLottable04 ' +
      ',TRANSFERDETAIL.ToLottable05 ' +
      ',RTRIM(TRANSFERDETAIL.ToLottable06) ' +
      ',RTRIM(TRANSFERDETAIL.ToLottable07) ' +
      ',RTRIM(TRANSFERDETAIL.ToLottable08) ' +
      ',RTRIM(TRANSFERDETAIL.ToLottable09) ' +
      ',RTRIM(TRANSFERDETAIL.ToLottable10) ' +
      ',RTRIM(TRANSFERDETAIL.ToLottable11) ' +
      ',RTRIM(TRANSFERDETAIL.ToLottable12) ' +
      ',TRANSFERDETAIL.ToLottable13 ' +
      ',TRANSFERDETAIL.ToLottable14 ' +
      ',TRANSFERDETAIL.ToLottable15 ' +
      ',TRANSFER.EditDate '

   SET @c_SQLStatement = @c_SQLStatement +
            'FROM ' + @c_ArchiveDB + '.dbo.V_TRANSFER TRANSFER WITH (NOLOCK) ' +
            'JOIN ' + @c_ArchiveDB + '.dbo.V_TRANSFERDETAIL TRANSFERDETAIL WITH (NOLOCK)  ON TRANSFERDETAIL.TransferKey = TRANSFER.TransferKey ' +
            'JOIN dbo.Facility WITH (NOLOCK) ON Facility.Facility = TRANSFER.Facility ' +
            ' WHERE TRANSFER.Status = ''9'' ' +
            'AND CONVERT(VARCHAR, TRANSFER.EditDate, 112) = CONVERT(VARCHAR, @d_Fromdate, 112) ' +
            @c_SQLCondition

      SET @c_SQLParm = '@n_WMS_BatchNo BIGINT, @n_TPB_Key NVARCHAR(5), @c_COUNTRYISO Nvarchar(5), @d_Fromdate DATETIME, @d_Todate DATETIME'

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
     ,DOC_SUB_TYPE
     ,DOC_REASON
     ,DOCUMENT_ID
     ,DOCUMENT_LINE_NO
     ,CLIENT_ID
     ,TO_CLIENT_ID
     ,REFERENCE_DATE
     ,SKU_ID
     ,BILLABLE_QUANTITY
     ,QTY_UOM
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
     ,ID
      ,TO_ID
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