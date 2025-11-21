SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Stored Procedure: isp_RPT_ASN_TALLYSHT_006                              */
/* Creation Date: 04-FEB-2022                                              */
/* Copyright: LFL                                                          */
/* Written by: Harshitha                                                   */
/*                                                                         */
/* Purpose: WMS-18869                                                      */
/*                                                                         */
/* Called By: RPT_ASN_TALLYSHT_006                                         */
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
CREATE PROC [dbo].[isp_RPT_ASN_TALLYSHT_006]
           @c_Receiptkey    NVARCHAR(10)

AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_Storerkey       NVARCHAR(15)

   SELECT Storerkey
         ,ShowSkuBarcode = ISNULL(MAX(CASE WHEN Code = 'ShowSkuBarcode' THEN 1 ELSE 0 END),0)
   INTO #TMP_RPTCFG
   FROM CODELKUP WITH (NOLOCK)
   WHERE ListName = 'REPORTCFG'
   AND   Long     = 'RPT_ASN_TALLYSHT_006'
   AND   (Short    IS NULL OR Short = 'N')
   GROUP BY Storerkey

   SELECT RECEIPT.ReceiptKey
         ,RECEIPTDETAIL.POKey
         ,RECEIPTDETAIL.Sku
         ,SKU.DESCR
         ,RECEIPTDETAIL.UOM
         ,RECEIPTDETAIL.Lottable02
         ,RECEIPTDETAIL.Lottable04
         ,RECEIPTDETAIL.Lottable05
         ,STORER.Company
         ,RECEIPT.ReceiptDate
         ,RECEIPTDETAIL.PackKey
         ,SKU.SUSR3
         ,RECEIPTDETAIL.QtyExpected
         ,RECEIPTDETAIL.BeforeReceivedQty
         ,UserID = (user_name())
         ,PACK.Packuom1
         ,PACK.Casecnt
         ,PACK.Packuom4
         ,PACK.Pallet
         ,PACK.Packuom2
         ,PACK.InnerPack
         ,RECEIPT.Signatory
         ,SKU.IVAS
         ,PACK.Qty PackQty
         ,RECEIPTDETAIL.QtyReceived
         ,SKU.PackQtyIndicator
         ,Receipt.facility
         ,Receipt.Storerkey
         ,Receipt.ExternReceiptKey
         ,Receipt.PoKey POKEY
         ,Receipt.WarehouseReference
         ,Receipt.Containerkey
         ,ContainerType = (SELECT TOP 1 CODELKUP.Description
                           FROM CODELKUP (NOLOCK)
                           WHERE CODELKUP.Listname = 'CONTAINERT'
                           AND CODELKUP.Code = Receipt.ContainerType
                           AND (CODELKUP.StorerKey = Receipt.StorerKey
                                OR ISNULL(CODELKUP.StorerKey,'')= '')
                           ORDER BY CODELKUP.StorerKey DESC)
         ,Sku.ShelfLife
         ,Pack.PalletHI
         ,Pack.PalletTI
         ,ExpectedCase = CASE PACK.Casecnt WHEN 0
                                           THEN 0
                                           ELSE CAST(RECEIPTDETAIL.QtyExpected / PACK.Casecnt as int)
                                           END
         ,ExpectedPack = CASE PACK.InnerPack WHEN 0 THEN 0 ELSE
                                  CASE PACK.Casecnt WHEN 0
                                                    THEN (cast(RECEIPTDETAIL.QtyExpected as int) / cast(PACK.InnerPack as int))
                                                    ELSE ((cast(RECEIPTDETAIL.QtyExpected as int) % cast(PACK.Casecnt as int) ) / cast(PACK.InnerPack as int))
                                                    END
                         END
         ,ExpectedEA = CASE PACK.InnerPack WHEN 0
                                           THEN CASE PACK.Casecnt WHEN 0 THEN cast(RECEIPTDETAIL.QtyExpected as int)
                                                                         ELSE (cast(RECEIPTDETAIL.QtyExpected as int) % cast(PACK.Casecnt as int)) END
                                           ELSE CASE PACK.Casecnt WHEN 0 THEN (cast(RECEIPTDETAIL.QtyExpected as int) % cast(PACK.InnerPack as int))
                                                                         ELSE (cast(RECEIPTDETAIL.QtyExpected as int) % cast(PACK.InnerPack as int)) END
                       END
         ,ReceivedCase = CASE PACK.Casecnt WHEN 0
                                           THEN 0
                                           ELSE CAST(RECEIPTDETAIL.BeforeReceivedQty / PACK.Casecnt as int)
                         END
         ,ReceivedPack = CASE PACK.InnerPack WHEN 0 THEN 0
                                                    ELSE CASE PACK.Casecnt WHEN 0 THEN (cast(RECEIPTDETAIL.BeforeReceivedQty as int) / cast(PACK.InnerPack as int))
                                                                                  ELSE ((cast(RECEIPTDETAIL.BeforeReceivedQty as int) % cast(PACK.Casecnt as int) ) / cast(PACK.InnerPack as int)) END
                         END
         ,ReceivedEA = CASE PACK.InnerPack WHEN 0 THEN CASE PACK.Casecnt WHEN 0 THEN CAST(RECEIPTDETAIL.BeforeReceivedQty AS INT)
                                                                                ELSE (cast(RECEIPTDETAIL.BeforeReceivedQty as int) % cast(PACK.Casecnt as int)) END
                                                  ELSE CASE PACK.Casecnt WHEN 0 THEN (cast(RECEIPTDETAIL.BeforeReceivedQty as int) % cast(PACK.InnerPack as int))
                                                                                ELSE (cast(RECEIPTDETAIL.BeforeReceivedQty as int) % cast(PACK.InnerPack as int)) END
                       END
         ,ISNULL(RC.ShowSkuBarcode,0)
         ,RECEIPTDETAIL.ToID
         ,SKU.RetailSKU
   FROM RECEIPT        WITH (NOLOCK)
   JOIN RECEIPTDETAIL  WITH (NOLOCK) ON RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey
   JOIN SKU            WITH (NOLOCK) ON SKU.StorerKey = RECEIPTDETAIL.StorerKey and SKU.Sku = RECEIPTDETAIL.Sku
   JOIN STORER         WITH (NOLOCK) ON RECEIPT.Storerkey = STORER.Storerkey
   JOIN PACK           WITH (NOLOCK) ON pack.packkey = sku.packkey
   LEFT OUTER JOIN #TMP_RPTCFG RC WITH(NOLOCK) ON (RECEIPT.Storerkey = RC.Storerkey)
   WHERE ( RECEIPT.ReceiptKey = @c_Receiptkey )
   AND ( RECEIPTDETAIL.QtyExpected > 0 )

END

GO