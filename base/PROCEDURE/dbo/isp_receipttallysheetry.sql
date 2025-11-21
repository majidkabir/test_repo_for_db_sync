SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_ReceiptTallySheetRY                            */
/* Creation Date: 10/12/2018                                            */
/* Copyright: IDS                                                       */
/* Written by: WLCHOOI                                                  */
/*                                                                      */
/* Purpose: WMS-3513-REMY_Exceed_TallySheet                             */
/*                                                                      */
/* Called By: r_cn_receipt_tallysheetry                                 */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_ReceiptTallySheetRY] (
   @c_containerkey NVARCHAR(40),
   @c_storerkey NVARCHAR(15),
   @c_facility  NVARCHAR(30)
   )
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @ReceiptKeyA NVARCHAR(120)
   CREATE TABLE #RYReceiptkey ( ReceiptKeyA   NVARCHAR(120) NULL)

   SELECT @ReceiptKeyA = ISNULL(STUFF( (SELECT RECEIPTKEY  +', '
   FROM RECEIPT WITH (NOLOCK)
   WHERE CONTAINERKEY=@c_containerkey AND FACILITY= @c_facility
   FOR XML PATH ('') ),1,0,'' ),'')
   SELECT @ReceiptKeyA= substring(@ReceiptKeyA, 1, (len(@ReceiptKeyA) - 1))
   INSERT INTO #RYReceiptkey VALUES (@ReceiptKeyA)

   SELECT (Storer.company + RECEIPT.StorerKey) as storerkey,
         RECEIPT.ContainerKey,
         RECEIPT.Facility ,
         RECEIPT.ReceiptDate,
         RECEIPT.ReceiptKey,
         ReceiptKeyA = (SELECT ReceiptKeyA FROM #RYReceiptkey) ,
         'PO' as PO,
         RECEIPT.POKey,
         RECEIPTDETAIL.Lottable01,
         RECEIPTDETAIL.Sku,
      RECEIPTDETAIL.Lottable08,
      SKU.Descr,
      RECEIPTDETAIL.Lottable02,
      RECEIPTDETAIL.Lottable04,
      PACK.Casecnt,
      CASE WHEN PACK.Casecnt = 0 THEN 1 ELSE CEILING(SUM(RECEIPTDETAIL.QtyExpected)/PACK.Casecnt) END AS QTYPERCASE,
      SUM(RECEIPTDETAIL.QtyExpected) AS QtyExpected,
      ROUND(SKU.STDGROSSWGT,3) as STDGROSSWGT,
      ROUND(SKU.STDCUBE,4) as STDCUBE
   FROM RECEIPT WITH (NOLOCK)
   JOIN RECEIPTDETAIL WITH (NOLOCK) ON ( RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey )
   JOIN SKU WITH (NOLOCK) ON ( SKU.StorerKey = RECEIPTDETAIL.StorerKey
    AND SKU.Sku = RECEIPTDETAIL.Sku )
   JOIN STORER WITH (NOLOCK) ON ( RECEIPT.Storerkey = STORER.Storerkey )
   JOIN PACK WITH (NOLOCK) ON ( SKU.Packkey = PACK.Packkey )
   WHERE ( RECEIPT.containerkey = @c_containerkey )
   AND ( RECEIPT.Storerkey >= @c_storerkey )
   AND RECEIPT.FACILITY = @c_facility
   GROUP BY  (Storer.company + RECEIPT.StorerKey),
          RECEIPT.ContainerKey,
          RECEIPT.Facility ,
          RECEIPT.ReceiptDate,
          RECEIPT.ReceiptKey,
          RECEIPT.POKey,
          RECEIPTDETAIL.Lottable01,
          RECEIPTDETAIL.Sku,
          RECEIPTDETAIL.Lottable08,
          SKU.Descr,
          RECEIPTDETAIL.Lottable02,
          RECEIPTDETAIL.Lottable04,
          PACK.Casecnt,
          RECEIPTDETAIL.QtyExpected,
          SKU.STDGROSSWGT,
          SKU.STDCUBE
   ORDER BY RECEIPT.ReceiptKey,RECEIPTDETAIL.Sku

   IF OBJECT_ID('tempdb..#RYReceiptkey','u') IS NOT NULL
   DROP TABLE #RYReceiptkey;

END

GO