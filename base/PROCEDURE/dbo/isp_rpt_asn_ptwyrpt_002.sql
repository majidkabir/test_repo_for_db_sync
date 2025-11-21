SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_RPT_ASN_PTWYRPT_002                            */
/* Creation Date: 14-Oct-2022                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WZPang                                                   */
/*                                                                      */
/* Purpose: WMS-20938 - MY - KFMY Putaway Advice Reformat		         */
/*                                                                      */
/* Called By: RPT_ASN_PTWYRPT_002                                       */
/*                                                                      */
/* GitLab Version: 1.3                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 11-Jan-2023	 WZPang	 1.1  WMS-21438 - MY - Modify UserName		      */
/* 11-Jan-2023  WZPang	 1.2  DevOps Combine Script					      */
/* 31-Oct-2023  WLChooi  1.3  UWP-10213 - Global Timezone (GTZ01)       */
/************************************************************************/
CREATE   PROC [dbo].[isp_RPT_ASN_PTWYRPT_002]
(
   @c_ReceiptKey NVARCHAR(10)
 , @c_Username   NVARCHAR(20) = ''
)
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
      Storerkey       NVARCHAR(15)  NULL
    , SKU             NVARCHAR(20)  NULL
    , DESCR           NVARCHAR(60)  NULL
    , Packkey         NVARCHAR(10)  NULL
    , BUSR6           NVARCHAR(18)  NULL
    , IVAS            NVARCHAR(30)  NULL
    , RetailSku       NVARCHAR(20)  NULL
    , ManufacturerSku NVARCHAR(20)  NULL
    , ShelfLife       INT           NULL
    , COMBINESKU      NVARCHAR(100) NULL
   )

   DECLARE CUR_RECSTORER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT RECEIPT.StorerKey
   FROM RECEIPT (NOLOCK)
   WHERE (RECEIPT.ReceiptKey = @c_ReceiptKey)

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
         SET @c_InsertSelect = N' INSERT INTO #TEMP_SKU SELECT DISTINCT SKU.Storerkey, SKU.Sku, SKU.Descr, SKU.Packkey, SKU.Busr6, SKU.IVAS, SKU.RetailSku, SKU.ManufacturerSku, SKU.ShelfLife '
         SET @c_FromWhere = N' FROM SKU (NOLOCK) '
                            + N' JOIN RECEIPTDETAIL RD (NOLOCK) ON SKU.Storerkey = RD.Storerkey AND SKU.Sku = RD.Sku '
                            + N' JOIN RECEIPT R (NOLOCK) ON RD.Receiptkey = R.Receiptkey '
                            + N' WHERE R.Receiptkey = RTRIM(@c_Receiptkey) '
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
                          , N'@c_storerkey nvarchar(15), @c_ReceiptKey nvarchar(10) '
                          , @c_storerkey
                          , @c_ReceiptKey

      END

      IF @c_ISCombineSKU = 'N'
      BEGIN
         INSERT INTO #TEMP_SKU
         SELECT DISTINCT SKU.StorerKey
                       , SKU.Sku
                       , SKU.DESCR
                       , SKU.PACKKey
                       , SKU.BUSR6
                       , SKU.IVAS
                       , SKU.RETAILSKU
                       , SKU.MANUFACTURERSKU
                       , SKU.ShelfLife
                       , SKU.Sku
         FROM SKU (NOLOCK)
         JOIN RECEIPTDETAIL RD (NOLOCK) ON SKU.StorerKey = RD.StorerKey AND SKU.Sku = RD.Sku
         JOIN RECEIPT R (NOLOCK) ON RD.ReceiptKey = R.ReceiptKey
         WHERE R.ReceiptKey = @c_ReceiptKey AND R.StorerKey = @c_storerkey
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
                 , BUSR6
                 , IVAS
                 , RetailSku
                 , ManufacturerSku
                 , ShelfLife
                 , COMBINESKU
   INTO #TEMP_SKU2
   FROM #TEMP_SKU

   SELECT RECEIPT.ReceiptKey
        , RECEIPT.ExternReceiptKey
        , RECEIPTDETAIL.ReceiptLineNumber
        , SKU.COMBINESKU AS ReceiptDetailSKU
        , UPPER(RECEIPTDETAIL.StorerKey) AS Storerkey
        , SKU.DESCR AS SKU_Descr
        , RECEIPTDETAIL.ToId
        , RECEIPTDETAIL.ToLoc
        , RECEIPTDETAIL.QtyReceived
        , RECEIPTDETAIL.UOM
        , RECEIPTDETAIL.Lottable02
        , [dbo].[fnc_ConvSFTimeZone](RECEIPT.StorerKey, RECEIPT.Facility, RECEIPTDETAIL.Lottable04) AS Lottable04   --GTZ01
        , RECEIPTDETAIL.POKey
        , RECEIPTDETAIL.PutawayLoc
        , RECEIPTDETAIL.BeforeReceivedQty
        , [dbo].[fnc_ConvSFTimeZone](RECEIPT.StorerKey, RECEIPT.Facility, RECEIPT.ReceiptDate) AS ReceiptDate   --GTZ01
        , STORER.Company
        , SUSER_SNAME() AS UserName
        , RECEIPT.WarehouseReference
        , PACK.CaseCnt
        , PACK.InnerPack
        , PACK.Qty
        , PACK.Pallet
        , PACK.[Cube]
        , PACK.GrossWgt
        , PACK.NetWgt
        , PACK.OtherUnit1
        , PACK.OtherUnit2
        , PACK.PackUOM1
        , PACK.PackUOM2
        , PACK.PackUOM3
        , PACK.PackUOM4
        , PACK.PackUOM5
        , PACK.PackUOM6
        , PACK.PackUOM7
        , PACK.PackUOM8
        , PACK.PackUOM9
        , RECEIPT.Facility
        , FACILITY.Descr AS FACILITY_Descr
        , RECEIPT.Signatory
        , SKU.RetailSku
        , SKU.ManufacturerSku
        , SKU.BUSR6
        , SKU.IVAS
        , SKU.ShelfLife
        , LOC.PutawayZone
        , TaskDetail.ToLoc AS TaskDetailToLOC
        , CASE PACK.CaseCnt
               WHEN 0 THEN 0
               ELSE CAST(RECEIPTDETAIL.BeforeReceivedQty / PACK.CaseCnt AS INT)END ReceivedCase
        , CASE PACK.InnerPack
               WHEN 0 THEN 0
               ELSE
                  CASE PACK.CaseCnt
                       WHEN 0 THEN (CAST(RECEIPTDETAIL.BeforeReceivedQty AS INT) / CAST(PACK.InnerPack AS INT))
                       ELSE
        ( (CAST(RECEIPTDETAIL.BeforeReceivedQty AS INT) % CAST(PACK.CaseCnt AS INT)) / CAST(PACK.InnerPack AS INT)) END END ReceivedPack
        , CASE PACK.InnerPack
               WHEN 0 THEN CASE PACK.CaseCnt
                                WHEN 0 THEN CAST(RECEIPTDETAIL.BeforeReceivedQty AS INT)
                                ELSE (CAST(RECEIPTDETAIL.BeforeReceivedQty AS INT) % CAST(PACK.CaseCnt AS INT)) END
               ELSE CASE PACK.CaseCnt
                         WHEN 0 THEN (CAST(RECEIPTDETAIL.BeforeReceivedQty AS INT) % CAST(PACK.InnerPack AS INT))
                         ELSE (CAST(RECEIPTDETAIL.BeforeReceivedQty AS INT) % CAST(PACK.CaseCnt AS INT)) END END ReceivedEA
        , [dbo].[fnc_ConvSFTimeZone](RECEIPT.StorerKey, RECEIPT.Facility, GETDATE()) AS CurrentDateTime   --GTZ01
   FROM RECEIPT (NOLOCK)
   JOIN RECEIPTDETAIL (NOLOCK) ON (RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey)
   JOIN #TEMP_SKU2 SKU (NOLOCK) ON (SKU.Storerkey = RECEIPTDETAIL.StorerKey) AND (SKU.SKU = RECEIPTDETAIL.Sku)
   JOIN STORER (NOLOCK) ON (RECEIPT.StorerKey = STORER.StorerKey)
   JOIN PACK (NOLOCK) ON (PACK.PackKey = SKU.Packkey)
   JOIN FACILITY (NOLOCK) ON (RECEIPT.Facility = FACILITY.Facility)
   LEFT JOIN LOC (NOLOCK) ON (RECEIPTDETAIL.PutawayLoc = LOC.Loc)
   LEFT JOIN TaskDetail (NOLOCK) ON (TaskDetail.FromID = RECEIPTDETAIL.ToId AND TaskDetail.TaskType = 'ASTPA1')
   WHERE RECEIPT.ReceiptKey = @c_ReceiptKey


END -- procedure  

GO