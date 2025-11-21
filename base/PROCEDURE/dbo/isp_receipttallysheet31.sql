SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_ReceiptTallySheet31    								*/
/* Creation Date: 10/12/2010                                            */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: SOS#186545                                                  */
/*                                                                      */
/* Called By: r_receipt_tallysheet31                                    */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 12-Jan-2011  NJOW01  1.0   Use left join link to po and exlcude link */
/*                            if empty value                            */
/* 04-Apr-2011  AQSKC   1.1   SOS#210437 Add Pick Loc (KC01)            */
/************************************************************************/

CREATE PROC [dbo].[isp_ReceiptTallySheet31] (
   @c_receiptkeystart NVARCHAR(10),
   @c_receiptkeyend NVARCHAR(10),
   @c_storerkeystart NVARCHAR(15),
   @c_storerkeyend NVARCHAR(15)
   )
 AS
 BEGIN
    SET NOCOUNT ON 
    SET QUOTED_IDENTIFIER OFF 
    SET ANSI_NULLS OFF   
    SET CONCAT_NULL_YIELDS_NULL OFF
                
  SELECT RECEIPT.storerkey,
         RECEIPT.facility,
         RECEIPT.receiptkey,
         RECEIPT.pokey,
         RECEIPT.externreceiptkey,
         PO.sellersreference,
         PO.sellername,
         PO.vesseldate,
         RECEIPTDETAIL.sku,
         SKU.descr,
         RECEIPTDETAIL.packkey,
         SKU.busr6,
         SUM(RECEIPTDETAIL.QtyExpected) AS QtyExpected, 
			CONVERT(DECIMAL(18,2),SUM(RECEIPTDETAIL.QtyExpected / CASE WHEN PACK.Casecnt=0 THEN 1 ELSE PACK.Casecnt END)) AS QtyCarton,
			CONVERT(DECIMAL(18,2),SUM(RECEIPTDETAIL.QtyExpected / CASE WHEN PACK.Innerpack=0 THEN 1 ELSE PACK.Innerpack END)) AS QtyInner,
         (SELECT TOP 1 UPC.upc FROM UPC (NOLOCK) WHERE UPC.Storerkey = RECEIPT.Storerkey AND UPC.Sku = RECEIPTDETAIL.Sku
          ORDER BY UPC.Editdate DESC, UPC.upc) AS UPC1,
         SKUXLOC.LOC as Pickloc        --(Kc01)
    INTO #TMP_TS1
    FROM RECEIPT (NOLOCK)
         JOIN RECEIPTDETAIL (NOLOCK) ON RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey  
         JOIN SKU (NOLOCK) ON  SKU.StorerKey = RECEIPTDETAIL.StorerKey AND  
                               SKU.Sku = RECEIPTDETAIL.Sku  
         --JOIN PO (NOLOCK) ON RECEIPT.ExternReceiptkey = PO.ExternPOKey
         LEFT JOIN PO (NOLOCK) ON (RECEIPT.ExternReceiptkey = PO.ExternPOKey AND ISNULL(RECEIPT.ExternReceiptkey,'')<>'')
			JOIN PACK (NOLOCK) ON PACK.PackKey = SKU.PackKey
         LEFT OUTER JOIN SKUXLOC(NOLOCK) 
         ON (SKUXLOC.SKU = SKU.SKU AND SKUXLOC.Storerkey = SKU.Storerkey AND SKUXLOC.LocationType = 'PICK')       --(KC01)
   WHERE RECEIPT.Receiptkey BETWEEN @c_receiptkeystart AND @c_receiptkeyend
   AND RECEIPT.Storerkey BETWEEN @c_storerkeystart AND @c_storerkeyend 
  GROUP BY RECEIPT.storerkey,
           RECEIPT.facility,
           RECEIPT.receiptkey,
           RECEIPT.pokey,
           RECEIPT.externreceiptkey,
           PO.sellersreference,
           PO.sellername,
           PO.vesseldate,
           RECEIPTDETAIL.sku,
           SKU.descr,
           RECEIPTDETAIL.packkey,
           SKU.busr6,
           SKUXLOC.LOC              --(KC01)

   SELECT #TMP_TS1.*, 
         (SELECT TOP 1 UPC.upc FROM UPC (NOLOCK) 
          WHERE UPC.Storerkey = #TMP_TS1.Storerkey AND UPC.Sku = #TMP_TS1.Sku
          AND UPC.upc <> #TMP_TS1.UPC1
          ORDER BY UPC.Editdate DESC, UPC.upc) AS UPC2
   INTO #TMP_TS2
   FROM #TMP_TS1

   SELECT #TMP_TS2.*, 
         (SELECT TOP 1 UPC.upc FROM UPC (NOLOCK) 
          WHERE UPC.Storerkey = #TMP_TS2.Storerkey AND UPC.Sku = #TMP_TS2.Sku
          AND UPC.upc <> #TMP_TS2.UPC1 AND UPC.upc <> #TMP_TS2.UPC2
          ORDER BY UPC.Editdate DESC, UPC.upc) AS UPC3
   FROM #TMP_TS2
   
 END        

GO