SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_receipt_discrepancy                                 */
/* Creation Date: 21-Mar-2023                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-22057 MYS-ECCOMY-Extend Column Size to Display Item     */
/*          Convert from query to SP                                    */
/*                                                                      */
/* Called By: r_dw_receipt_discrepancy                                  */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 21-Mar-2023 WLChooi  1.0   DevOps Combine Script                     */
/************************************************************************/
CREATE   PROCEDURE [dbo].[isp_receipt_discrepancy] @c_Receiptkey NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SELECT RECEIPTDETAIL.Sku
        , RECEIPTDETAIL.QtyExpected
        , CASE WHEN FinalizeFlag = 'Y' THEN RECEIPTDETAIL.QtyReceived
               ELSE RECEIPTDETAIL.BeforeReceivedQty END AS QtyReceived
        , RECEIPTDETAIL.EditDate
        , RECEIPTDETAIL.ToLoc
        , RECEIPTDETAIL.ToId
        , RECEIPTDETAIL.ToLot
        , RECEIPTDETAIL.PutawayLoc
        , RECEIPTDETAIL.POKey
        , RECEIPT.ReceiptKey
        , RECEIPT.ExternReceiptKey
        , RECEIPT.Status
        , SKU.DESCR
        , PACK.PackUOM1
        , PACK.CaseCnt
        , PACK.PackUOM3
        , STORER.Company
        , LOC.Facility
        , PA_QTY = CASE RECEIPTDETAIL.PutawayLoc
                        WHEN ' ' THEN 0
                        ELSE RECEIPTDETAIL.QtyReceived END
        , RECEIPT.WarehouseReference
        , RECEIPT.ContainerKey
        , RECEIPT.ContainerType
        , PACK.Pallet
        , RECEIPT.Signatory
        , RECEIPT.StorerKey
        , ISNULL(CL.Short, '') AS SHOWCS
        , ISNULL(C1.Short, 'Y') AS ExtendSKUField
   FROM RECEIPT (NOLOCK)
   JOIN RECEIPTDETAIL (NOLOCK) ON RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey
   JOIN SKU (NOLOCK) ON SKU.StorerKey = RECEIPTDETAIL.StorerKey AND SKU.Sku = RECEIPTDETAIL.Sku
   JOIN PACK (NOLOCK) ON PACK.PackKey = SKU.PACKKey
   JOIN LOC (NOLOCK) ON LOC.Loc = RECEIPTDETAIL.ToLoc
   JOIN STORER (NOLOCK) ON STORER.StorerKey = RECEIPTDETAIL.StorerKey
   LEFT JOIN CODELKUP CL (NOLOCK) ON  CL.LISTNAME = 'REPORTCFG'
                                  AND CL.Code = 'SHOWCS'
                                  AND CL.Long = 'r_dw_receipt_discrepancy'
                                  AND CL.Storerkey = RECEIPTDETAIL.StorerKey
   LEFT JOIN CODELKUP C1 (NOLOCK) ON  C1.LISTNAME = 'REPORTCFG'
                                  AND C1.Code = 'ExtendSKUField'
                                  AND C1.Long = 'r_dw_receipt_discrepancy'
                                  AND C1.Storerkey = RECEIPTDETAIL.StorerKey
   WHERE RECEIPT.ReceiptKey = @c_Receiptkey
   GROUP BY RECEIPTDETAIL.Sku
          , RECEIPTDETAIL.QtyExpected
          , RECEIPTDETAIL.FinalizeFlag
          , RECEIPTDETAIL.BeforeReceivedQty
          , RECEIPTDETAIL.QtyReceived
          , RECEIPTDETAIL.EditDate
          , RECEIPTDETAIL.ToLoc
          , RECEIPTDETAIL.ToId
          , RECEIPTDETAIL.ToLot
          , RECEIPTDETAIL.PutawayLoc
          , RECEIPTDETAIL.POKey
          , RECEIPT.ReceiptKey
          , RECEIPT.ExternReceiptKey
          , RECEIPT.Status
          , SKU.DESCR
          , PACK.PackUOM1
          , PACK.CaseCnt
          , PACK.PackUOM3
          , STORER.Company
          , LOC.Facility
          , RECEIPT.WarehouseReference
          , RECEIPT.ContainerKey
          , RECEIPT.ContainerType
          , PACK.Pallet
          , RECEIPT.Signatory
          , RECEIPT.StorerKey
          , ISNULL(CL.Short, '')
          , ISNULL(C1.Short, 'Y')
   ORDER BY RECEIPT.ReceiptKey, RECEIPTDETAIL.Sku, RECEIPTDETAIL.ToLoc, RECEIPTDETAIL.ToId
END -- procedure

GO