SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Stored Procedure: isp_RPT_ASN_TALLYSHT_005                              */
/* Creation Date: 07-JAN-2022                                              */
/* Copyright: LFL                                                          */
/* Written by: Harshitha                                                   */
/*                                                                         */
/* Purpose: WMS-18713                                                      */
/*                                                                         */
/* Called By: RPT_ASN_TALLYSHT_005                                         */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 1.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 07-Jan-2022  WLChooi 1.0   DevOps Combine Script                        */
/***************************************************************************/

CREATE PROC [dbo].[isp_RPT_ASN_TALLYSHT_005]
    @c_Receiptkey      NVARCHAR(20)

AS
BEGIN

  SET NOCOUNT ON
  SET ANSI_NULLS OFF
  SET QUOTED_IDENTIFIER OFF
  SET CONCAT_NULL_YIELDS_NULL OFF

   SELECT RECEIPT.ReceiptKey,
          RECEIPTDETAIL.POKey RD_POKEY,
          RECEIPTDETAIL.Sku,
          SKU.DESCR,
          RECEIPTDETAIL.UOM,
          RECEIPTDETAIL.Lottable02,
          RECEIPTDETAIL.Lottable03,
          RECEIPTDETAIL.Lottable04,
          RECEIPTDETAIL.Lottable05,
          STORER.Company,
          RECEIPT.ReceiptDate,
          RECEIPTDETAIL.PackKey,
          SKU.SUSR3,
          RECEIPTDETAIL.QtyExpected ,
          RECEIPTDETAIL.BeforeReceivedQty,
          (user_name()) UserID,
          PACK.Packuom1,
          PACK.Casecnt,
          PACK.Packuom4,
          PACK.Pallet,
          PACK.Packuom2,
          PACK.InnerPack,
          RECEIPT.CarrierReference,
          SKU.IVAS,
          PACK.Qty PackQty,
          RECEIPTDETAIL.QtyReceived,
          SKU.PackQtyIndicator,
          Receipt.facility,
          Receipt.Storerkey,
          Receipt.ExternReceiptKey,
          Receipt.PoKey POKEY,
          Receipt.WarehouseReference,
          Receipt.Containerkey,
          (SELECT TOP 1 CODELKUP.Description FROM CODELKUP (NOLOCK) WHERE CODELKUP.listname='CONTAINERT' AND CODELKUP.code = RECEIPT.ContainerType AND (CODELKUP.StorerKey = RECEIPT.StorerKey OR ISNULL(CODELKUP.StorerKey,'')='') ORDER BY CODELKUP.Storerkey DESC) AS ContainerType,
          Sku.ShelfLife,
          Pack.PalletHI,
          Pack.PalletTI,
          CASE PACK.Casecnt WHEN 0 THEN 0
          	ELSE CAST(RECEIPTDETAIL.QtyExpected / PACK.Casecnt as int)
          END ExpectedCase,
          CASE PACK.InnerPack when 0 THEN 0
          ELSE
          		CASE PACK.Casecnt WHEN 0 THEN (cast(RECEIPTDETAIL.QtyExpected as int) / cast(PACK.InnerPack as int))
          								ELSE ((cast(RECEIPTDETAIL.QtyExpected as int) % cast(PACK.Casecnt as int) ) / cast(PACK.InnerPack as int)) END
          END ExpectedPack,
          CASE PACK.InnerPack when 0 THEN
          		CASE PACK.Casecnt WHEN 0 THEN cast(RECEIPTDETAIL.QtyExpected as int)
          								ELSE (cast(RECEIPTDETAIL.QtyExpected as int) % cast(PACK.Casecnt as int)) END
          ELSE
          		CASE PACK.Casecnt WHEN 0 THEN (cast(RECEIPTDETAIL.QtyExpected as int) % cast(PACK.InnerPack as int))
          								ELSE (cast(RECEIPTDETAIL.QtyExpected as int) % cast(PACK.InnerPack as int)) END
          END ExpectedEA,
          CASE PACK.Casecnt WHEN 0 THEN 0
          	ELSE CAST(RECEIPTDETAIL.BeforeReceivedQty / PACK.Casecnt as int)
          END ReceivedCase,
          CASE PACK.InnerPack when 0 THEN 0
          ELSE
          		CASE PACK.Casecnt WHEN 0 THEN (cast(RECEIPTDETAIL.BeforeReceivedQty as int) / cast(PACK.InnerPack as int))
          								ELSE ((cast(RECEIPTDETAIL.BeforeReceivedQty as int) % cast(PACK.Casecnt as int) ) / cast(PACK.InnerPack as int)) END
          END ReceivedPack,
          CASE PACK.InnerPack when 0 THEN
          		CASE PACK.Casecnt WHEN 0 THEN cast(RECEIPTDETAIL.BeforeReceivedQty as int)
          								ELSE (cast(RECEIPTDETAIL.BeforeReceivedQty as int) % cast(PACK.Casecnt as int)) END
          ELSE
          		CASE PACK.Casecnt WHEN 0 THEN (cast(RECEIPTDETAIL.BeforeReceivedQty as int) % cast(PACK.InnerPack as int))
          								ELSE (cast(RECEIPTDETAIL.BeforeReceivedQty as int) % cast(PACK.InnerPack as int)) END
          END ReceivedEA
   FROM RECEIPT (NOLOCK)
   JOIN RECEIPTDETAIL (NOLOCK) ON RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey
   JOIN SKU (NOLOCK) ON SKU.StorerKey = RECEIPTDETAIL.StorerKey and SKU.Sku = RECEIPTDETAIL.Sku
   JOIN STORER (NOLOCK) ON RECEIPT.Storerkey = STORER.Storerkey
   JOIN	PACK (NOLOCK)  ON pack.packkey = sku.packkey
   WHERE ( RECEIPT.ReceiptKey = @c_Receiptkey )
   AND ( RECEIPTDETAIL.QtyExpected > 0 )
   ORDER BY RECEIPTDETAIL.RECEIPTKEY, RECEIPTDETAIL.ReceiptLineNumber, RECEIPTDETAIL.ExternLineNo

END

GO