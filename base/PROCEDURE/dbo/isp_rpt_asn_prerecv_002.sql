SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Stored Procedure: isp_RPT_ASN_PRERECV_002                               */
/* Creation Date: 04-FEB-2022                                              */
/* Copyright: LFL                                                          */
/* Written by: Harshitha                                                   */
/*                                                                         */
/* Purpose: WMS-18872                                                      */
/*                                                                         */
/* Called By: RPT_ASN_PRERECV_002                                          */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 1.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author      Ver. Purposes                                  */
/* 07-Feb-2022  WLChooi     1.0  DevOps Combine Script                     */
/***************************************************************************/

CREATE PROC [dbo].[isp_RPT_ASN_PRERECV_002]
      @c_Receiptkey        NVARCHAR(10),
      @c_ReceiptLineStart  NVARCHAR(10),
      @c_ReceiptLineEnd    NVARCHAR(10)
AS
BEGIN

   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF ISNULL(@c_ReceiptLineStart,'') = '' SET @c_ReceiptLineStart = '00001'
   IF ISNULL(@c_ReceiptLineEnd,'') = ''   SET @c_ReceiptLineEnd = '99999'

   SELECT RECEIPTDETAIL.ReceiptKey,
          RECEIPTDETAIL.ReceiptLineNumber,
          TRIM(RECEIPTDETAIL.StorerKey) AS StorerKey,
          TRIM(RECEIPTDETAIL.Sku) AS SKU,
          RECEIPTDETAIL.ToLoc,
          RECEIPTDETAIL.PutawayLoc,
          RECEIPTDETAIL.Lottable01,
          RECEIPTDETAIL.Lottable02,
          RECEIPTDETAIL.Lottable03,
          RECEIPTDETAIL.Lottable04,
          CONVERT(NVARCHAR(7),CONVERT(datetime,RECEIPTDETAIL.Lottable04,111),111) AS LOT04MTH,
          RECEIPTDETAIL.Lottable05,
          RECEIPTDETAIL.QtyExpected,
          RECEIPTDETAIL.QtyReceived,
          RECEIPTDETAIL.BeforeReceivedQty,
          TRIM(RECEIPTDETAIL.TOID) AS TOID,
          RECEIPT.WarehouseReference,
          SKU.DESCR,
          SKU.Lottable01Label,
          SKU.Lottable02Label,
          SKU.Lottable03Label,
          SKU.Lottable04Label,
          SKU.Lottable05Label,
          PACK.CaseCnt,
          PACK.Qty,
          PACK.PalletTI,
          PACK.PalletHI,
          PACK.PackDescr,
          Loc.Putawayzone,
          Sku.Putawayzone,
          LOC.Facility,
          Loc_b.Putawayzone,
          RECEIPT.ReceiptDate  ,
          RECEIPTDETAIL.Lottable06
   FROM RECEIPT WITH (NOLOCK)
   JOIN RECEIPTDETAIL WITH (NOLOCK) ON (RECEIPT.Receiptkey = RECEIPTDETAIL.Receiptkey)
   JOIN SKU  WITH (NOLOCK) ON (RECEIPTDETAIL.StorerKey = SKU.StorerKey)
                           AND(RECEIPTDETAIL.Sku = SKU.Sku)
   JOIN PACK WITH (NOLOCK) ON (PACK.PackKey = SKU.PACKKey)
   JOIN LOC  WITH (NOLOCK) ON (LOC.Loc = RECEIPTDETAIL.ToLoc)
   LEFT JOIN LOC LOC_b WITH (NOLOCK) ON (LOC_b.Loc = RECEIPTDETAIL.PutawayLoc)
   WHERE ( ( RECEIPTDETAIL.ReceiptKey = @c_Receiptkey )
   AND   ( RECEIPTDETAIL.ReceiptlineNumber >= @c_ReceiptLineStart )
   AND   ( RECEIPTDETAIL.ReceiptLineNumber <= @c_ReceiptLineEnd   )
   AND   (RECEIPTDETAIL.TOID <> '' ))
   ORDER BY RECEIPTDETAIL.TOID

END

GO