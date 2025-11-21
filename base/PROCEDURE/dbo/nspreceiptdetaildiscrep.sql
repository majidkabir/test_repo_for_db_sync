SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspReceiptDetailDiscrep                            */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[nspReceiptDetailDiscrep] (
@StorerKeyMin           NVARCHAR(15),
@StorerKeyMax           NVARCHAR(15),
@ReceiptKeyMin          NVARCHAR(18),
@ReceiptKeyMax          NVARCHAR(18),
@ReceiptDateMin         NVARCHAR(20),
@ReceiptDateMax         NVARCHAR(20)
) AS
BEGIN
	 SET NOCOUNT ON
	 SET QUOTED_IDENTIFIER OFF	
   SET CONCAT_NULL_YIELDS_NULL OFF

   SELECT DISTINCT
   Receipt.Receiptkey
   INTO #ReceiptCandidates
   FROM Receipt
   WHERE
   Receipt.StorerKey Between @StorerKeyMin AND @StorerKeyMax
   AND Receipt.ReceiptKey Between @ReceiptKeyMin AND  @ReceiptKeyMax
   AND Receipt.ReceiptDate >= Convert( datetime, @ReceiptDateMin )
   AND Receipt.ReceiptDate <  DateAdd( day, 1, Convert( datetime, @ReceiptDateMax ) )
   SELECT
   Receiptdetail.Receiptkey,
   SUM(Receiptdetail.qtyreceived) qtyrcvd,
   SUM(Receiptdetail.qtyexpected) qtyexpd
   INTO #Receiptqtyrcvd
   FROM Receiptdetail
   WHERE
   Receiptdetail.ReceiptKEY IN (SELECT ReceiptKEY FROM #ReceiptCANDIDATES)
   GROUP BY Receiptdetail.Receiptkey
   SELECT
   Receipt.ReceiptKey,
   Receipt.StorerKey,
   Receipt.ReceiptDate,
   Receipt.CarrierReference,
   Receipt.CarrierName,
   ReceiptDETAIL.Sku,
   ReceiptDETAIL.QtyExpected,
   ReceiptDETAIL.QtyAdjusted,
   ReceiptDETAIL.QtyReceived,
   SKU.DESCR,
   STORER.Company
   FROM Receipt, ReceiptDETAIL, STORER, SKU
   WHERE
   Receipt.ReceiptKey IN (SELECT ReceiptKey FROM #Receiptqtyrcvd WHERE qtyrcvd > 0 AND qtyrcvd <> qtyexpd)
   AND Receipt.ReceiptKey = ReceiptDETAIL.ReceiptKey
   AND Receipt.StorerKey = STORER.StorerKey
   AND ReceiptDETAIL.StorerKey = SKU.StorerKey
   AND ReceiptDETAIL.Sku = SKU.Sku
END

GO