SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_TPB_Receipt_Carters                            */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: TPB billing for CHN Carter Receipt Transaction              */
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
/* 3-Apr-2018   TLTING    1.1   Revise externreceiptkey logic           */
/* 08-Jun-18    TLTING    1.2   pass in billdate                        */
/* 07-Jul-18    TLTING    1.3   LOT_LOTTABLE_01, LOT_LOTTABLE_02        */
/* 19-Feb-2020  TLTING02  1.4   Bug fix , cause by table schema change  */
/************************************************************************/

CREATE PROC [dbo].[isp_TPB_Receipt_Carters_Archive]
   @n_WMS_BatchNo BIGINT,
   @n_TPB_Key     BIGINT,
   @d_BillDate    DATE,
   @n_RecCOUNT    INT = 0 OUTPUT,
   @c_storerkey   NVARCHAR(15)  = '',
   @n_debug       INT = 0,
   @c_ArchiveDB   NVARCHAR(30) = ''

AS
BEGIN
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET NOCOUNT ON

   DECLARE @d_Todate DATETIME
   DECLARE @d_Fromdate DATETIME
   DECLARE @c_COUNTRYISO NVARCHAR(5)

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

   -- Get ExternReceiptkey
   CREATE TABLE #ExternReceipt
   ( Rowref             INT NOT NULL IDENTITY(1,1) PRIMARY KEY,
      Receiptkey        NVARCHAR( 10) NOT NULL,
      ReceiptLineNumber NVARCHAR(5) NOT NULL,
      ExternReceiptKey  NVARCHAR (20)  NULL,
      ExternLineNo      NVARCHAR(20)   NULL
   )

   SET @c_SQLStatement = ''
   SET @c_SQLParm = ''

   SET @c_SQLStatement =
   N'SELECT Receipt.ReceiptKey, RD.ReceiptLineNumber, RD.ExternReceiptKey, RD.ExternLineNo ' +
   'FROM ' + @c_ArchiveDB + '.dbo.V_Receipt Receipt WITH (NOLOCK) ' +
   'JOIN ' + @c_ArchiveDB + '.dbo.V_Receiptdetail RD (NOLOCK) ON RD.receiptkey = Receipt.ReceiptKey ' +
   'WHERE Receipt.ASNStatus = ''9'' ' + @c_SQLCondition +
   'AND CONVERT(VARCHAR, RD.DateReceived, 112) = CONVERT(VARCHAR, @d_Fromdate, 112) ' +
   'ORDER BY Receipt.ReceiptKey, RD.ReceiptLineNumber '

   SET @c_SQLParm = '@d_Fromdate DATETIME, @d_Todate DATETIME'

   -- same receipt filter as main SELECT
   INSERT INTO #ExternReceipt (Receiptkey, ReceiptLineNumber, ExternReceiptKey, ExternLineNo)
   EXEC sp_ExecuteSQL @c_SQLStatement, @c_SQLParm, @d_Fromdate, @d_Todate

   -- If is NULL, replace with 1st externreceiptkey (not null)
   UPDATE #ExternReceipt
   SET ExternReceiptKey = ( SELECT TOP 1 R2.ExternReceiptKey FROM #ExternReceipt R2
                            WHERE R2.Receiptkey = #ExternReceipt.Receiptkey
                            AND R2.ExternReceiptKey is NOT NULL AND R2.ExternReceiptKey <> ''
                            ORDER BY R2.ReceiptLineNumber ),
         ExternLineNo = ( SELECT TOP 1 R2.ExternLineNo FROM #ExternReceipt R2
                          WHERE R2.Receiptkey = #ExternReceipt.Receiptkey
                          AND R2.ExternReceiptKey is NOT NULL AND R2.ExternReceiptKey <> ''
                          ORDER BY R2.ReceiptLineNumber )
   FROM #ExternReceipt
   WHERE ExternReceiptKey IS NULL OR ExternReceiptKey = ''

   SET @c_SQLStatement = ''
   SET @c_SQLParm = ''

   SET @c_SQLStatement =
   N'SELECT @n_WMS_BatchNo' +
   ',@n_TPB_Key '+
   ',''A'' ' +          -- A = ACTIVITIES
   ',''RECEIPT'' ' +
   ',@c_COUNTRYISO ' +
   ',UPPER(RTRIM(RECEIPT.Facility)) ' +
   ',RECEIPT.AddDate ' +
   ',RECEIPT.AddWho ' +
   ',RECEIPT.EditDate ' +
   ',RECEIPT.EditWho ' +
   ',''WMS'' ' +
   ',RTRIM(RECEIPT.ASNStatus) ' +
   ',RTRIM(RECEIPT.DocType) ' +
   ',RTRIM(RECEIPT.RECType) ' +
   ',RTRIM(RECEIPT.ReceiptGroup) ' +
   ',RTRIM(RECEIPT.ReceiptKey) ' +
   ',RTRIM(RD.ReceiptLineNumber) ' +
   ',RTRIM(TRD.ExternReceiptKey) ' +
   ',RTRIM(TRD.ExternLineNo) ' +
   ',UPPER(RTRIM(RECEIPT.StorerKey)) ' +
   ',RTRIM(PO.SellerName) ' +
   ',RTRIM(PO.SellerCompany) ' +
   ',UPPER(RTRIM(RECEIPT.Facility)) ' +
   ',RTRIM(RECEIPT.WarehouseReference) ' +
   ',RTRIM(RD.POKey) ' +
   ',RTRIM(RD.ExternPoKey) ' +
   ',RECEIPT.ReceiptDate' +
   ',UPPER(RTRIM(RD.SKU)) ' +
   ',RD.QtyReceived '  +
   ',RTRIM(RD.UOM) ' +
   ',0 ' +   --  ','''' ' +
   ',SKU.GrossWgt ' +
   ',RECEIPT.ContainerQty ' +
   ',RTRIM(RD.VesselKey) ' +
   ',RTRIM(RD.VoyageKey) ' +
   ',RTRIM(RECEIPT.VehicleNumber) ' +
   ',RTRIM(RECEIPT.VehicleDate) ' +
   ',RTRIM(RECEIPT.ContainerType) ' +
   ',RTRIM(RECEIPT.ContainerKey) ' +
   ',RTRIM(RD.Lottable01) ' +
   ',RTRIM(RD.Lottable02) ' +
   ',RTRIM(RD.Lottable03) ' +
   ',RD.Lottable04 ' +
   ',RD.Lottable05 ' +
   ',RTRIM(RD.Lottable06) ' +
   ',RTRIM(RD.Lottable07) ' +
   ',RTRIM(RD.Lottable08) ' +
   ',RTRIM(RD.Lottable09) ' +
   ',RTRIM(RD.Lottable10) ' +
   ',RTRIM(RD.Lottable11) ' +
   ',RTRIM(RD.Lottable12) ' +
   ',RD.Lottable13 ' +
   ',RD.Lottable14 ' +
   ',RD.Lottable15 ' +
   ',RTRIM(RECEIPT.UserDefine01) ' +
   ',RTRIM(RECEIPT.UserDefine02) ' +
   ',RTRIM(RECEIPT.UserDefine03) ' +
   ',RTRIM(RECEIPT.UserDefine04) ' +
   ',RTRIM(RECEIPT.UserDefine05) ' +
   ',RTRIM(RECEIPT.UserDefine06) ' +
   ',RTRIM(RECEIPT.UserDefine07) ' +
   ',RTRIM(RECEIPT.UserDefine08) ' +
   ',RTRIM(RECEIPT.UserDefine09) ' +
   ',RTRIM(RECEIPT.UserDefine10) ' +
   ',RTRIM(RD.UserDefine01) ' +
   ',RTRIM(RD.UserDefine02) ' +
   ',RTRIM(RD.UserDefine03) ' +
   ',RTRIM(RD.UserDefine04) ' +
   ',RTRIM(RD.UserDefine05) ' +
   ',RTRIM(RD.UserDefine06) ' +
   ',RTRIM(RD.UserDefine07) ' +
   ',RTRIM(RD.UserDefine08) ' +
   ',RTRIM(RD.UserDefine09) ' +
   ',RTRIM(RD.UserDefine10) ' +
   ',ISNULL(RTRIM(Storer.SUSR1),'''')' +
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
   ',RTRIM(SKU.Size) ' +
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
   ',RTRIM(F.UserDefine01) ' +
   ',ISNULL(RTRIM(PO.SellerAddress1),'''' ) ' +
   ',RTRIM(L.Lottable01) ' +
   ',RTRIM(L.Lottable02) ' +
   ',RECEIPT.EDITDATE '

   SET @c_SQLStatement = @c_SQLStatement +
      N' FROM ' + @c_ArchiveDB + '.dbo.V_RECEIPT RECEIPT WITH (NOLOCK) ' +
     'JOIN ' + @c_ArchiveDB + '.dbo.V_RECEIPTDETAIL RD WITH (NOLOCK) ON RD.RECEIPTKey = RECEIPT.RECEIPTKey ' +
     'JOIN dbo.PACK WITH (NOLOCK) ON PACK.PACKKey = RD.PACKKey ' +
     'JOIN dbo.SKU sku WITH (NOLOCK) ON SKU.StorerKey = RD.StorerKey AND SKU.SKU = RD.SKU ' +
     'LEFT JOIN dbo.FACILITY F WITH (NOLOCK) ON F.Facility =RECEIPT.Facility ' +
     'JOIN ' + @c_ArchiveDB + '.dbo.V_ITRN ITRN WITH (NOLOCK) ON ITRN.SourceKey = RD.Receiptkey + RD.ReceiptLineNumber ' +
     'AND ITRN.SourceType= ''ntrReceiptDetailUpdate'' AND ITRN.trantype =''DP'' ' +
     'JOIN dbo.LOTATTRIBUTE L WITH (NOLOCK) ON L.lot = ITRN.lot ' +
     'LEFT JOIN #ExternReceipt AS TRD ON TRD.ReceiptKey = RECEIPT.ReceiptKey AND TRD.ReceiptLineNumber = RD.ReceiptLineNumber ' +
     'LEFT JOIN ' + @c_ArchiveDB + '.dbo.V_PO PO WITH (NOLOCK) ON PO.ExternPOKey = TRD.ExternReceiptKey AND  PO.StorerKey = RECEIPT.StorerKey ' +
     'LEFT JOIN Storer WITH (NOLOCK) ON Storer.storerkey = ''CA'' + RD.lottable01 ' +
     'WHERE RECEIPT.ASNStatus =''9'' ' +
     'AND RD.QtyReceived > 0  ' +
     'AND CONVERT(VARCHAR, RD.DateReceived, 112) = CONVERT(VARCHAR, @d_Fromdate, 112) ' +
      @c_SQLCondition

      SET @c_SQLParm = '@n_WMS_BatchNo BIGINT, @n_TPB_Key NVARCHAR(5), @c_COUNTRYISO NVARCHAR(5), @d_Fromdate DATETIME, @d_Todate DATETIME' +
                        ', @c_Storerkey NVARCHAR(15) '

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

   INSERT INTO [dbo].[WMS_TPB_BASE](
    BatchNo
   ,CONFIG_ID
   ,TRANSACTION_TYPE
   ,CODE
   ,COUNTRY
   ,SITE_ID
   ,ADD_DATE
   ,ADD_WHO
   ,EDIT_DATE                    --TPB Date diff: RECEIPT.EditDate - RECEIPT.ReceiptDate
   ,EDIT_WHO
   ,DOC_SOURCE
   ,DOC_STATUS
   ,DOC_TYPE
   ,DOC_SUB_TYPE
   ,DOC_GROUPING_1
   ,DOCUMENT_ID
   ,DOCUMENT_LINE_NO
   ,CLIENT_REF
   ,CLIENT_REF_LINE_NO
   ,CLIENT_ID
   ,SHIP_FROM_ID
   ,SHIP_FROM_COMPANY
   ,SHIP_TO_ID
   ,OTHER_REFERENCE_1
   ,PO_NO
   ,CLIENT_PO_NO
   ,REFERENCE_DATE
   ,SKU_ID
   ,BILLABLE_QUANTITY
   ,QTY_UOM
   ,BILLABLE_CARTON
   ,BILLABLE_WEIGHT
   ,BILLABLE_CONTAINER
   ,VESSEL_ID
   ,VOYAGE_ID
   ,VEHICLE_NO
   ,VEHICLE_DATE
   ,CONTAINER_TYPE
   ,CONTAINER_ID
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
   ,STR_SUSR1
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
   ,FT_USD_20
   ,LOT_LOTTABLE_01
   ,LOT_LOTTABLE_02
   ,BILLABLE_DATE
   )
    EXEC sp_ExecuteSQL @c_SQLStatement, @c_SQLParm, @n_WMS_BatchNo, @n_TPB_Key, @c_COUNTRYISO, @d_Fromdate, @d_Todate, @c_storerkey
    SET @n_RecCOUNT = @@ROWCOUNT

   IF @n_debug = 1
   BEGIN
      PRINT 'Record Count - ' + CAST(@n_RecCOUNT AS NVARCHAR)
      PRINT ''
   END
END

GO