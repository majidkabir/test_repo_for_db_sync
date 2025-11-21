SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_RPT_ASN_TALLYSHT_031                            */
/* Creation Date: 02-Aug-2023                                            */
/* Copyright: MAERSK                                                     */
/* Written by: CSCHONG                                                   */
/*                                                                       */
/* Purpose: WMS-23179-SG LIXIL - Inbound tally sheet report change       */
/*                                                                       */
/* Called By: RPT_ASN_TALLYSHT_031                                       */
/*                                                                       */
/* GitLab Version: 1.0                                                   */
/*                                                                       */
/* Version:  5.4                                                         */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date        Author  Ver   Purposes                                    */
/* 02-Aug-2023 CSCHONG 1.0   DevOps Combine Script                       */
/* 26-Sep-2023 WLChooi 1.1   WMS-23721 - Change sorting (WL01)           */
/*************************************************************************/
CREATE   PROC [dbo].[isp_RPT_ASN_TALLYSHT_031]
(
   @c_ReceiptKey   NVARCHAR(10)   --WL01
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue     INT         = 1
         , @c_GetSKU       NVARCHAR(20)
         , @c_GetStorerkey NVARCHAR(15)
         , @n_NoOfPF       INT         = 0
         , @c_Indicator    NVARCHAR(1) = N'N'
         , @c_SQL          NVARCHAR(MAX) = N''   --WL01
         , @c_SQLSorting   NVARCHAR(MAX) = N''   --WL01

   CREATE TABLE #TMP_SKU
   (
      SKU               NVARCHAR(20)
    , Storerkey         NVARCHAR(15)
    , PickFaceIndicator NVARCHAR(1) NULL DEFAULT ('N')
   )

   CREATE NONCLUSTERED INDEX IDX_TMP_SKU ON #TMP_SKU (SKU, Storerkey)

   --WL01 S
   SELECT @c_GetStorerkey = Storerkey
   FROM RECEIPT (NOLOCK)
   WHERE Receiptkey = @c_ReceiptKey

   SELECT @c_SQLSorting = ISNULL(CL.Notes,'')
   FROM CODELKUP CL (NOLOCK)
   WHERE CL.LISTNAME = 'REPORTCFG'
   AND CL.Code = 'RPTSORTING'
   AND CL.Storerkey = @c_GetStorerkey
   AND CL.Long = 'RPT_ASN_TALLYSHT_031'
   AND CL.Short = 'Y'

   IF ISNULL(@c_SQLSorting, '') = ''
      SET @c_SQLSorting = N' ORDER BY ReceiptKey, ReceiptLineNumber '
   --WL01 E

   IF EXISTS (  SELECT 1
                FROM CODELKUP (NOLOCK)
                WHERE LISTNAME = 'REPORTCFG'
                AND   Code = 'ShowPickFaceIndicator'
                AND   Long = 'RPT_ASN_TALLYSHT_031'
                AND   Short = 'Y'
                AND   Storerkey = @c_GetStorerkey)   --WL01
   BEGIN
      INSERT INTO #TMP_SKU (SKU, Storerkey)
      SELECT DISTINCT RECEIPTDETAIL.Sku
                    , RECEIPT.StorerKey
      FROM RECEIPT (NOLOCK)
      JOIN RECEIPTDETAIL (NOLOCK) ON RECEIPTDETAIL.ReceiptKey = RECEIPT.ReceiptKey
      WHERE (RECEIPT.ReceiptKey = @c_ReceiptKey)   --WL01
      AND   (RECEIPT.RECType = 'NORMAL' OR RECEIPT.RECType = 'RETURN')

      DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT T.SKU
           , T.Storerkey
      FROM #TMP_SKU T (NOLOCK)
      JOIN CODELKUP CL (NOLOCK) ON  CL.LISTNAME = 'REPORTCFG'
                                AND CL.Code = 'ShowPickFaceIndicator'
                                AND CL.Long = 'RPT_ASN_TALLYSHT_031'
                                AND CL.Short = 'Y'
                                AND CL.Storerkey = T.Storerkey

      OPEN CUR_LOOP

      FETCH NEXT FROM CUR_LOOP
      INTO @c_GetSKU
         , @c_GetStorerkey

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @c_Indicator = N'N'

         SELECT @n_NoOfPF = COUNT(1)
         FROM SKUxLOC SL (NOLOCK)
         JOIN LOC L (NOLOCK) ON L.Loc = SL.Loc
         WHERE SL.Sku = @c_GetSKU
         AND   SL.StorerKey = @c_GetStorerkey
         AND   L.LocationType IN ( 'PICK' )
         AND   (SL.Qty - SL.QtyAllocated - SL.QtyPicked) > 0
         AND   L.Loc LIKE 'C%'

         IF @n_NoOfPF > 0
         BEGIN
            SET @c_Indicator = N'Y'
         END

         UPDATE #TMP_SKU
         SET PickFaceIndicator = @c_Indicator
         WHERE SKU = @c_GetSKU AND Storerkey = @c_GetStorerkey

         SET @n_NoOfPF = 0

         FETCH NEXT FROM CUR_LOOP
         INTO @c_GetSKU
            , @c_GetStorerkey
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP

   END

   SELECT STORER.Company
        , RECEIPT.ReceiptKey
        , ISNULL(RECEIPT.CarrierReference, '') AS CarrierReference
        , RECEIPT.StorerKey
        , RECEIPT.CarrierName
        , RECEIPT.EditWho
        , RECEIPT.ReceiptDate
        , RECEIPTDETAIL.Sku
        , RECEIPTDETAIL.Lottable02
        , SKU.DESCR
        , RECEIPTDETAIL.Lottable04
        , RECEIPTDETAIL.UOM
        , SUM(RECEIPTDETAIL.QtyExpected) AS QtyExp
        , RECEIPT.CarrierAddress1
        , RECEIPT.POKey
        , RECEIPTDETAIL.Lottable03
        , ISNULL(RECEIPT.Signatory, '') AS Signatory
        , RECEIPT.UserDefine01
        , RECEIPT.Facility
        , RECEIPTDETAIL.Lottable01
        , RECEIPT.ContainerKey
        , RECEIPT.ContainerType AS containertype
        , RECEIPTDETAIL.ReceiptLineNumber --
        , CASE WHEN ISNULL(SKU.BUSR9, '') IN ( 'Yes', 'Y' ) THEN 'OLD'
               ELSE 'NEW' END AS SkuFlag
        , SKU.GrossWgt AS SGrossWgt
        , SKU.Length AS SLength
        , RECEIPT.ExternReceiptKey
        , SKU.Width AS SWidth
        , SKU.Height AS SHeight
        , SKU.ShelfLife
        , CONVERT(NVARCHAR(10), DATEADD(DAY, SKU.ShelfLife, RECEIPT.ReceiptDate), 101) AS ExpDate
        , ISNULL(SKU.IVAS, '') AS IVAS
        , SKU.BUSR1
        , SKU.PutawayZone sku_putawayzone
        , RECEIPTDETAIL.AltSku
        , RECEIPT.UserDefine03 AS RHUDF03
        , ISNULL(CL.Short, 'N') AS ShowPickFaceIndicator
        , ISNULL(TS.PickFaceIndicator, 'N') AS PickFaceIndicator
        , RECEIPTDETAIL.Lottable06 AS LOTT06
   INTO #TMP_RECEIPT   --WL01
   FROM RECEIPT (NOLOCK)
   JOIN RECEIPTDETAIL (NOLOCK) ON RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey
   JOIN STORER (NOLOCK) ON RECEIPTDETAIL.StorerKey = STORER.StorerKey
   JOIN SKU (NOLOCK) ON SKU.StorerKey = RECEIPTDETAIL.StorerKey AND SKU.Sku = RECEIPTDETAIL.Sku
   LEFT JOIN #TMP_SKU TS (NOLOCK) ON TS.SKU = RECEIPTDETAIL.Sku AND TS.Storerkey = RECEIPT.StorerKey
   LEFT JOIN CODELKUP CL (NOLOCK) ON  CL.LISTNAME = 'REPORTCFG'
                                  AND CL.Code = 'ShowPickFaceIndicator'
                                  AND CL.Long = 'RPT_ASN_TALLYSHT_031'
                                  AND CL.Short = 'Y'
                                  AND CL.Storerkey = RECEIPT.StorerKey
   WHERE (RECEIPT.ReceiptKey = @c_ReceiptKey)   --WL01
   AND   (RECEIPT.RECType = 'NORMAL' OR RECEIPT.RECType = 'RETURN')
   GROUP BY STORER.Company
          , RECEIPT.ReceiptKey
          , ISNULL(RECEIPT.CarrierReference, '')
          , RECEIPT.StorerKey
          , RECEIPT.CarrierName
          , RECEIPT.ReceiptDate
          , RECEIPTDETAIL.Sku
          , RECEIPTDETAIL.Lottable02
          , SKU.DESCR
          , RECEIPTDETAIL.Lottable04
          , RECEIPTDETAIL.UOM
          , RECEIPT.CarrierAddress1
          , RECEIPT.POKey
          , RECEIPTDETAIL.Lottable03
          , ISNULL(RECEIPT.Signatory, '')
          , RECEIPT.UserDefine01
          , RECEIPT.Facility
          , RECEIPTDETAIL.Lottable01
          , RECEIPT.ContainerKey
          , RECEIPT.ContainerType
          , RECEIPTDETAIL.ReceiptLineNumber
          -- ISNULL(CLR.Code,''),
          , RECEIPT.ExternReceiptKey
          , SKU.ShelfLife
          , SKU.IVAS
          , SKU.BUSR1
          , SKU.PutawayZone
          , RECEIPTDETAIL.AltSku
          , RECEIPT.EditWho
          , CASE WHEN ISNULL(SKU.BUSR9, '') IN ( 'Yes', 'Y' ) THEN 'OLD'
                 ELSE 'NEW' END
          , SKU.GrossWgt
          , SKU.Length
          , SKU.Width
          , SKU.Height
          , RECEIPT.UserDefine03
          , ISNULL(CL.Short, 'N')
          , ISNULL(TS.PickFaceIndicator, 'N')
          , RECEIPTDETAIL.Lottable06
   ORDER BY RECEIPT.ReceiptKey
          , RECEIPTDETAIL.ReceiptLineNumber

   --WL01 S
   SET @c_SQL = N' SELECT * FROM #TMP_RECEIPT '

   SET @c_SQL = @c_SQL + @c_SQLSorting

   EXEC sp_executesql @c_SQL
   --WL01 E

   IF OBJECT_ID('tempdb..#TMP_SKU') IS NOT NULL
      DROP TABLE #TMP_SKU
   
   --WL01
   IF OBJECT_ID('tempdb..#TMP_RECEIPT') IS NOT NULL
      DROP TABLE #TMP_RECEIPT
END

GO