SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Proc: isp_ReceiptTallySheet62                                 */
/* Creation Date: 17-Jun-2019                                           */
/* Copyright: LF Logistics                                              */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-9446 SG - THG - Inbound Tally Sheet                     */
/*        :                                                             */
/* Called By: r_receipt_tallysheet62                                    */
/*            copy from r_receipt_tallysheet50                          */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 12-OCT-2020  CSCHONG   1.1 WMS-15461 - add new field (CS01)          */
/* 19-Jan-2021  WLChooi   1.2 WMS-16089 - Show PickFace Indicator (WL01)*/
/* 02-AUG-2023  CSCHONG   1.3 WMS-23179 add new field (CS02)            */
/************************************************************************/

CREATE   PROC [dbo].[isp_ReceiptTallySheet62]
            @c_ReceiptKeyStart   NVARCHAR(10)
         ,  @c_ReceiptKeyEnd     NVARCHAR(10)
         ,  @c_StorerKeyStart    NVARCHAR(15)
         ,  @c_StorerKeyEnd      NVARCHAR(15)
         ,  @c_UserID            NVARCHAR(80) = ''

AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   --WL01 S
   DECLARE @n_Continue      INT = 1,
           @c_GetSKU        NVARCHAR(20),
           @c_GetStorerkey  NVARCHAR(15),
           @n_NoOfPF        INT = 0,
           @c_Indicator     NVARCHAR(1) = 'N'

   CREATE TABLE #TMP_SKU (
      SKU                  NVARCHAR(20),
      Storerkey            NVARCHAR(15),
      PickFaceIndicator    NVARCHAR(1) NULL DEFAULT('N') )

   CREATE NONCLUSTERED INDEX IDX_TMP_SKU ON #TMP_SKU (SKU, Storerkey)

   IF EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE LISTNAME = 'REPORTCFG' AND Code = 'ShowPickFaceIndicator'
                                                AND Long = 'r_receipt_tallysheet62' AND Short = 'Y'
                                                AND Storerkey BETWEEN @c_StorerKeyStart AND @c_StorerKeyEnd)
   BEGIN
      INSERT INTO #TMP_SKU (SKU, Storerkey)
      SELECT DISTINCT RECEIPTDETAIL.SKU, RECEIPT.Storerkey
      FROM RECEIPT (NOLOCK)
      JOIN RECEIPTDETAIL (NOLOCK) ON RECEIPTDETAIL.ReceiptKey = RECEIPT.ReceiptKey
      WHERE ( RECEIPT.ReceiptKey >= @c_ReceiptKeyStart ) AND
            ( REceipt.receiptkey <= @c_ReceiptKeyEnd ) AND
            ( RECEIPT.Storerkey >=  @c_StorerKeyStart ) AND
            ( RECEIPT.Storerkey <=  @c_StorerKeyEnd ) AND
            (RECEIPT.RECType = "NORMAL" OR RECEIPT.RECType = "RETURN")

      DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT T.SKU, T.Storerkey
      FROM #TMP_SKU T (NOLOCK)
      JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'REPORTCFG' AND CL.Code = 'ShowPickFaceIndicator'
                               AND CL.Long = 'r_receipt_tallysheet62' AND CL.Short = 'Y'
                               AND CL.Storerkey = T.Storerkey

      OPEN CUR_LOOP

      FETCH NEXT FROM CUR_LOOP INTO @c_GetSKU, @c_GetStorerkey

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @c_Indicator = 'N'

         SELECT @n_NoOfPF = COUNT(1)
         FROM SKUxLoc SL (NOLOCK)
         JOIN LOC L (NOLOCK) ON L.LOC = SL.LOC
         WHERE SL.SKU = @c_GetSKU AND SL.StorerKey = @c_GetStorerkey
         AND L.LocationType IN ('PICK') AND (SL.Qty - SL.QtyAllocated - SL.QtyPicked) > 0
         AND L.LOC LIKE 'C%'

         IF @n_NoOfPF > 0
         BEGIN
            SET @c_Indicator = 'Y'
         END

         UPDATE #TMP_SKU
         SET PickFaceIndicator = @c_Indicator
         WHERE SKU = @c_GetSKU AND Storerkey = @c_GetStorerkey

         SET @n_NoOfPF = 0

         FETCH NEXT FROM CUR_LOOP INTO @c_GetSKU, @c_GetStorerkey
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP
      --SELECT * FROM #TMP_SKU
   END

   --WL01 E

   SELECT STORER.Company,
         RECEIPT.ReceiptKey,
         ISNULL(RECEIPT.CarrierReference,'') as CarrierReference,
         RECEIPT.StorerKey,
         RECEIPT.CarrierName,
         RECEIPT.Editwho,
         RECEIPT.ReceiptDate,
         RECEIPTDETAIL.Sku,
         RECEIPTDETAIL.Lottable02,
         SKU.DESCR,
         RECEIPTDETAIL.Lottable04,
         RECEIPTDETAIL.UOM,
         SUM(RECEIPTDETAIL.QtyExpected) AS QtyExp,
         RECEIPT.CarrierAddress1,
         RECEIPT.POkey,
         RECEIPTDETAIL.Lottable03,
         ISNULL(RECEIPT.Signatory,'') AS Signatory,
         RECEIPT.Userdefine01,
         RECEIPT.Facility,
         RECEIPTDETAIL.lottable01,
         RECEIPT.Containerkey,
         RECEIPT.ContainerType AS containertype,
         RECEIPTDETAIL.ReceiptLinenumber,--
         CASE WHEN ISNULL(SKU.BUSR9,'') in ('Yes','Y') THEN 'OLD' ELSE 'NEW' END AS SkuFlag,
         SKU.grosswgt as SGrossWgt,
         SKU.Length  as SLength,
       --  CONVERT(CHAR(20),@c_UserID) AS userid,
         RECEIPT.ExternReceiptKey,
         SKU.Width   as SWidth,
         SKU.Height  as SHeight,
         SKU.Shelflife,
         convert(nvarchar(10),DATEADD(DAY,SKU.Shelflife,RECEIPT.ReceiptDate),101) As ExpDate,
         ISNULL(SKU.IVAS,'') AS IVAS,
         SKU.BUSR1
         ,SKU.Putawayzone sku_putawayzone
         ,RECEIPTDETAIL.AltSku
         ,RECEIPT.Userdefine03 as RHUDF03             --(CS01)
         ,ISNULL(CL.Short,'N') AS ShowPickFaceIndicator           --WL01
         ,ISNULL(TS.PickFaceIndicator,'N') AS PickFaceIndicator   --WL01
         ,RECEIPTDETAIL.Lottable06 AS LOTT06  --CS02
   FROM RECEIPT (nolock)
   JOIN RECEIPTDETAIL (nolock) ON RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey
   JOIN STORER (nolock) ON RECEIPTDETAIL.StorerKey = STORER.StorerKey
   JOIN SKU (nolock) ON  SKU.StorerKey = RECEIPTDETAIL.StorerKey AND SKU.Sku = RECEIPTDETAIL.Sku
   LEFT JOIN #TMP_SKU TS (NOLOCK) ON TS.SKU = RECEIPTDETAIL.SKU AND TS.Storerkey = RECEIPT.StorerKey   --WL01
   LEFT JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'REPORTCFG' AND CL.Code = 'ShowPickFaceIndicator'   --WL01
                                 AND CL.Long = 'r_receipt_tallysheet62' AND CL.Short = 'Y'             --WL01
                                 AND CL.Storerkey = RECEIPT.Storerkey                                  --WL01
   WHERE ( RECEIPT.ReceiptKey >= @c_ReceiptKeyStart ) AND
         ( REceipt.receiptkey <= @c_ReceiptKeyEnd ) AND
         ( RECEIPT.Storerkey >=  @c_StorerKeyStart ) AND
         ( RECEIPT.Storerkey <=  @c_StorerKeyEnd ) AND
         (RECEIPT.RECType = "NORMAL" OR RECEIPT.RECType = "RETURN")
   GROUP BY STORER.Company,
         RECEIPT.ReceiptKey,
         ISNULL(RECEIPT.CarrierReference,''),
         RECEIPT.StorerKey,
         RECEIPT.CarrierName,
         RECEIPT.ReceiptDate,
         RECEIPTDETAIL.Sku,
         RECEIPTDETAIL.Lottable02,
         SKU.DESCR,
         RECEIPTDETAIL.Lottable04,
         RECEIPTDETAIL.UOM,
         RECEIPT.CarrierAddress1,
         RECEIPT.POkey,
         RECEIPTDETAIL.Lottable03,
         ISNULL(RECEIPT.Signatory,''),
         RECEIPT.Userdefine01,
         RECEIPT.Facility,
         RECEIPTDETAIL.lottable01,
         RECEIPT.Containerkey,
         RECEIPT.ContainerType,
         RECEIPTDETAIL.ReceiptLinenumber,
        -- ISNULL(CLR.Code,''),
         RECEIPT.ExternReceiptKey,
         SKU.Shelflife,
         SKU.IVAS,
         SKU.BUSR1
         ,SKU.Putawayzone
         ,RECEIPTDETAIL.AltSku
         ,RECEIPT.Editwho
         ,CASE WHEN ISNULL(SKU.BUSR9,'') in ('Yes','Y') THEN 'OLD' ELSE 'NEW' END,
         SKU.grosswgt,
         SKU.Length,
         SKU.Width,
         SKU.Height,
         RECEIPT.Userdefine03,              --(CS01)
         ISNULL(CL.Short,'N'),              --WL01
         ISNULL(TS.PickFaceIndicator,'N'),   --WL01
         RECEIPTDETAIL.Lottable06            --CS02
   ORDER BY RECEIPT.ReceiptKey, RECEIPTDETAIL.ReceiptLinenumber

   --WL01 S
   IF OBJECT_ID('tempdb..#TMP_SKU') IS NOT NULL
      DROP TABLE #TMP_SKU
   --WL01 E
END

GO