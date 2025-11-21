SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_RPT_ASN_RTNTALSHT_001                          */
/* Creation Date: 26-MAY-2022                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WZPang                                                   */
/*                                                                      */
/* Purpose: WMS-19860 - Migrate WMS report to Logi Report               */
/*                      r_receipt_tallysheet07 (MY)                     */
/*                                                                      */
/* Called By: RPT_ASN_RTNTALSHT_001                                     */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 26-May-2022  WZPang   1.0  DevOps Combine Script                     */
/************************************************************************/
CREATE PROC [dbo].[isp_RPT_ASN_RTNTALSHT_001]
(@c_receiptkey NVARCHAR(10))
AS
BEGIN

   SET NOCOUNT ON
   SET ANSI_NULLS ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_WARNINGS ON

   DECLARE @c_storerkey    NVARCHAR(15)
         , @c_udf01        NVARCHAR(60)
         , @c_udf02        NVARCHAR(60)
         , @c_udf03        NVARCHAR(60)
         , @c_TableName    NVARCHAR(100)
         , @c_ColName      NVARCHAR(100)
         , @c_ColType      NVARCHAR(100)
         , @c_ISCombineSKU NCHAR(1)
         , @cSQL           NVARCHAR(MAX)
         , @c_FromWhere    NVARCHAR(2000)
         , @c_InsertSelect NVARCHAR(2000)

   CREATE TABLE #TEMP_SKU
   (
      Storerkey  NVARCHAR(15)  NULL
    , SKU        NVARCHAR(20)  NULL
    , DESCR      NVARCHAR(60)  NULL
    , Packkey    NVARCHAR(10)  NULL
    , SUSR3      NVARCHAR(18)  NULL
    , IVAS       NVARCHAR(30)  NULL
    , COMBINESKU NVARCHAR(100) NULL
   )


   DECLARE CUR_RECSTORER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT RECEIPT.StorerKey
   FROM RECEIPT (NOLOCK)
   WHERE (RECEIPT.ReceiptKey = @c_receiptkey)

   OPEN CUR_RECSTORER

   FETCH NEXT FROM CUR_RECSTORER
   INTO @c_storerkey

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SELECT @c_udf01 = N''
           , @c_udf02 = N''
           , @c_udf03 = N''
           , @c_ISCombineSKU = N'N'
           , @c_InsertSelect = N''
           , @c_FromWhere = N''

      SELECT @c_udf01 = ISNULL(CL.UDF01, '')
           , @c_udf02 = ISNULL(CL.UDF02, '')
           , @c_udf03 = ISNULL(CL.UDF03, '')
      FROM CODELKUP CL (NOLOCK)
      WHERE LISTNAME = 'COMBINESKU' AND Code = 'CONCATENATESKU' AND Storerkey = @c_storerkey

      IF @@ROWCOUNT > 0
      BEGIN
         SET @c_ISCombineSKU = N'Y'
         SET @c_InsertSelect = N' INSERT INTO #TEMP_SKU SELECT DISTINCT SKU.Storerkey, SKU.Sku, SKU.Descr, SKU.Packkey, SKU.Susr3, SKU.IVAS '
         SET @c_FromWhere = N' FROM SKU (NOLOCK) '
                            + N' JOIN RECEIPTDETAIL RD (NOLOCK) ON SKU.Storerkey = RD.Storerkey AND SKU.Sku = RD.Sku '
                            + N' JOIN RECEIPT R (NOLOCK) ON RD.Receiptkey = R.Receiptkey '
                            + N' WHERE R.Receiptkey >= RTRIM(@c_receiptkeystart) '
                            + N' AND R.Receiptkey <= RTRIM(@c_receiptkeyend) '
                            + N' AND R.Storerkey = RTRIM(@c_storerkey) '

         SET @c_ColName = @c_udf01
         SET @c_TableName = N'SKU'
         IF CHARINDEX('.', @c_udf01) > 0
         BEGIN
            SET @c_TableName = LEFT(@c_udf01, CHARINDEX('.', @c_udf01) - 1)
            SET @c_ColName = SUBSTRING(@c_udf01, CHARINDEX('.', @c_udf01) + 1, LEN(@c_udf01) - CHARINDEX('.', @c_udf01))
         END

         SET @c_ColType = N''
         SELECT @c_ColType = DATA_TYPE
         FROM INFORMATION_SCHEMA.COLUMNS
         WHERE TABLE_NAME = @c_TableName AND COLUMN_NAME = @c_ColName

         IF @c_ColType IN ( 'char', 'nvarchar', 'varchar' ) AND @c_TableName = 'SKU'
            SELECT @c_InsertSelect = @c_InsertSelect + N',LTRIM(RTRIM(ISNULL(' + RTRIM(@c_udf01) + N',''''))) '
         ELSE
            SELECT @c_InsertSelect = @c_InsertSelect + N',''' + LTRIM(RTRIM(@c_udf01)) + N''' '


         SET @c_ColName = @c_udf02
         SET @c_TableName = N'SKU'
         IF CHARINDEX('.', @c_udf02) > 0
         BEGIN
            SET @c_TableName = LEFT(@c_udf02, CHARINDEX('.', @c_udf02) - 1)
            SET @c_ColName = SUBSTRING(@c_udf02, CHARINDEX('.', @c_udf02) + 1, LEN(@c_udf02) - CHARINDEX('.', @c_udf02))
         END

         SET @c_ColType = N''
         SELECT @c_ColType = DATA_TYPE
         FROM INFORMATION_SCHEMA.COLUMNS
         WHERE TABLE_NAME = @c_TableName AND COLUMN_NAME = @c_ColName

         IF @c_ColType IN ( 'char', 'nvarchar', 'varchar' ) AND @c_TableName = 'SKU'
            SELECT @c_InsertSelect = @c_InsertSelect + N' + LTRIM(RTRIM(ISNULL(' + RTRIM(@c_udf02) + N',''''))) '
         ELSE
            SELECT @c_InsertSelect = @c_InsertSelect + N' + ''' + LTRIM(RTRIM(@c_udf02)) + N''' '


         SET @c_ColName = @c_udf03
         SET @c_TableName = N'SKU'
         IF CHARINDEX('.', @c_udf03) > 0
         BEGIN
            SET @c_TableName = LEFT(@c_udf03, CHARINDEX('.', @c_udf03) - 1)
            SET @c_ColName = SUBSTRING(@c_udf03, CHARINDEX('.', @c_udf03) + 1, LEN(@c_udf03) - CHARINDEX('.', @c_udf03))
         END

         SET @c_ColType = N''
         SELECT @c_ColType = DATA_TYPE
         FROM INFORMATION_SCHEMA.COLUMNS
         WHERE TABLE_NAME = @c_TableName AND COLUMN_NAME = @c_ColName

         IF @c_ColType IN ( 'char', 'nvarchar', 'varchar' ) AND @c_TableName = 'SKU'
            SELECT @c_InsertSelect = @c_InsertSelect + N' + LTRIM(RTRIM(ISNULL(' + RTRIM(@c_udf03) + N',''''))) '
         ELSE
            SELECT @c_InsertSelect = @c_InsertSelect + N' + ''' + LTRIM(RTRIM(@c_udf03)) + N''' '

         SET @cSQL = @c_InsertSelect + @c_FromWhere

         EXEC sp_executesql @cSQL
                          , N'@c_storerkey nvarchar(15), @c_receiptkeystart nvarchar(10), @c_receiptkeyend nvarchar(10) '
                          , @c_storerkey
                          , @c_receiptkey
                          , @c_receiptkey

      END

      IF @c_ISCombineSKU = 'N'
      BEGIN
         INSERT INTO #TEMP_SKU
         SELECT DISTINCT SKU.StorerKey
                       , SKU.Sku
                       , SKU.DESCR
                       , SKU.PACKKey
                       , SKU.SUSR3
                       , SKU.IVAS
                       , SKU.Sku
         FROM SKU (NOLOCK)
         JOIN RECEIPTDETAIL RD (NOLOCK) ON SKU.StorerKey = RD.StorerKey AND SKU.Sku = RD.Sku
         JOIN RECEIPT R (NOLOCK) ON RD.ReceiptKey = R.ReceiptKey
         WHERE R.ReceiptKey = @c_receiptkey AND R.StorerKey = @c_storerkey
      END

      FETCH NEXT FROM CUR_RECSTORER
      INTO @c_storerkey
   END
   CLOSE CUR_RECSTORER
   DEALLOCATE CUR_RECSTORER

   SELECT DISTINCT Storerkey
                 , SKU
                 , DESCR
                 , Packkey
                 , SUSR3
                 , IVAS
                 , COMBINESKU
   INTO #TEMP_SKU2
   FROM #TEMP_SKU

   SELECT RECEIPT.ReceiptKey
        , RECEIPTDETAIL.POKey AS RECEIPTDETAIL_POKey
        , CASE WHEN ISNULL(SKU.COMBINESKU, '') = '' THEN SKU.SKU
               ELSE SKU.COMBINESKU END AS SKU
        , SKU.DESCR
        , RECEIPTDETAIL.UOM
        , RECEIPTDETAIL.Lottable01
        , RECEIPTDETAIL.Lottable02
        , RECEIPTDETAIL.Lottable03
        , RECEIPTDETAIL.Lottable04
        , RECEIPTDETAIL.Lottable05
        , STORER.Company
        , RECEIPT.ReceiptDate
        , RECEIPTDETAIL.PackKey
        , SKU.SUSR3
        , RECEIPTDETAIL.QtyExpected
        , RECEIPTDETAIL.BeforeReceivedQty
        , (USER_NAME()) username
        , PACK.PackUOM1
        , CASE WHEN ISNULL(CL.Short, 'N') = 'Y' AND ISNULL(PACK.CaseCnt, 0) > 0 THEN (PACK.Pallet / PACK.CaseCnt)
               ELSE PACK.CaseCnt END AS Casecnt
        , PACK.PackUOM4
        , PACK.Pallet
        , PACK.PackUOM2
        , PACK.InnerPack
        , RECEIPT.Signatory
        , SKU.IVAS
        , RECEIPTDETAIL.ToLoc ToLoc
        , RECEIPT.WarehouseReference
        , RECEIPTDETAIL.ToId
        , ISNULL(CL.Short, 'N') AS 'SHOWCTN/PLT'
        , ISNULL(RECEIPT.ExternReceiptKey, '') AS ExternReceiptkey
        , ISNULL(RECEIPT.ReceiptGroup, '') AS ReceiptGroup
        , ISNULL(RECEIPT.POKey, '') AS POKey
        , ISNULL(RECEIPT.RECType, '') AS RecType
        , ISNULL(CL1.Short, 'N') AS ShowExtraCol
        , ISNULL(CL2.Short, 'N') AS ShowSKUGroup
        , (  SELECT MAX(SKUGROUP)
             FROM SKU (NOLOCK)
             WHERE StorerKey = RECEIPT.StorerKey AND Sku = RECEIPTDETAIL.Sku) AS SKUGroup
        , RECEIPTDETAIL.StorerKey
   FROM RECEIPT WITH (NOLOCK)
   JOIN RECEIPTDETAIL WITH (NOLOCK) ON (RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey)
   JOIN #TEMP_SKU2 SKU WITH (NOLOCK) ON (SKU.Storerkey = RECEIPTDETAIL.StorerKey AND SKU.SKU = RECEIPTDETAIL.Sku)
   JOIN STORER WITH (NOLOCK) ON (RECEIPT.StorerKey = STORER.StorerKey)
   JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.PackKey)
   OUTER APPLY (  SELECT TOP 1 CL.Short
                  FROM CODELKUP CL WITH (NOLOCK)
                  WHERE (   CL.LISTNAME = 'REPORTCFG'
                        AND CL.Storerkey = RECEIPT.StorerKey
                        AND CL.Code = 'SHOWCTN/PLT'
                        AND (CL.code2 = RECEIPT.Facility OR CL.code2 = ''))
                  ORDER BY CASE WHEN CL.code2 = '' THEN 2
                                ELSE 1 END) AS CL
   LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON (   CL1.LISTNAME = 'REPORTCFG'
                                           AND CL1.Code = 'ShowExtraCol'
                                           AND CL1.Storerkey = RECEIPT.StorerKey
                                           AND CL1.Long = 'RPT_ASN_RTNTALSHT_001')
   LEFT JOIN CODELKUP CL2 WITH (NOLOCK) ON (   CL2.LISTNAME = 'REPORTCFG'
                                           AND CL2.Code = 'ShowSKUGroup'
                                           AND CL2.Storerkey = RECEIPT.StorerKey
                                           AND CL2.Long = 'RPT_ASN_RTNTALSHT_001')
   WHERE (RECEIPT.ReceiptKey = @c_receiptkey)

END -- procedure     

GO