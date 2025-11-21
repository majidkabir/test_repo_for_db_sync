SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_ReceivingLabel_25_rdt                          */
/* Creation Date: 16-Dec-2021                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-18594 - TH-SINO CR Putaway Label for RDT Rec,Re-Print   */
/*                                                                      */
/* Called By: r_dw_receivinglabel25_rdt                                 */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author    Ver.  Purposes                                 */
/* 16-Dec-2021 WLChooi   1.0   DevOps Combine Script                    */
/************************************************************************/

CREATE PROC [dbo].[isp_ReceivingLabel_25_rdt](
      @c_Receiptkey         NVARCHAR(10)
    , @c_Receiptline_From   NVARCHAR(18)   --Could be ReceiptDetail.ToId
    , @c_Receiptline_To     NVARCHAR(5) = ''
 )
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_NULLS OFF

   CREATE TABLE #TMP_RECEIPT (
      Receiptkey                 NVARCHAR(10)
    , ReceiptLineNumberStart     NVARCHAR(5)
    , ReceiptLineNumberEnd       NVARCHAR(5)
   )

   IF EXISTS (SELECT 1 FROM RECEIPTDETAIL RD (NOLOCK)
              WHERE RD.ReceiptKey = @c_Receiptkey
              AND RD.ToId = @c_Receiptline_From)
   BEGIN
      INSERT INTO #TMP_RECEIPT (Receiptkey, ReceiptLineNumberStart, ReceiptLineNumberEnd)
      SELECT RD.ReceiptKey, MIN(RD.ReceiptLineNumber), MAX(RD.ReceiptLineNumber)
      FROM RECEIPTDETAIL RD (NOLOCK)
      WHERE RD.ReceiptKey = @c_Receiptkey
      AND RD.ToId = @c_Receiptline_From
      GROUP BY RD.ReceiptKey
   END
   ELSE
   BEGIN
      INSERT INTO #TMP_RECEIPT (Receiptkey, ReceiptLineNumberStart, ReceiptLineNumberEnd)
      SELECT @c_Receiptkey, @c_Receiptline_From, @c_Receiptline_To
   END

   SELECT RECEIPTDETAIL.ReceiptKey,  
          RECEIPTDETAIL.ReceiptLineNumber,  
          RECEIPTDETAIL.StorerKey,   
          CASE WHEN ISNULL(CLR2.Code,'') <> '' THEN SKU.AltSku ELSE RECEIPTDETAIL.Sku END AS RECEIPTDETAIL_SKU,
          RECEIPTDETAIL.ToLoc,   
          RECEIPTDETAIL.PutawayLoc,   
          RECEIPTDETAIL.Lottable01,   
          RECEIPTDETAIL.Lottable02,   
          RECEIPTDETAIL.Lottable03,   
          RECEIPTDETAIL.Lottable04,   
          RECEIPTDETAIL.Lottable05,   
          (SELECT SUM( RD1.QtyExpected) FROM RECEIPTDETAIL RD1 (NOLOCK) WHERE RD1.ReceiptKey = @c_Receiptkey and RD1.ReceiptLineNumber = RECEIPTDETAIL.ReceiptLineNumber) QtyExpected, 
          (SELECT SUM( RD2.QtyReceived) FROM RECEIPTDETAIL RD2 (NOLOCK) WHERE RD2.ReceiptKey = @c_Receiptkey and RD2.ReceiptLineNumber = RECEIPTDETAIL.ReceiptLineNumber) QtyReceived, 
          (SELECT SUM( RD3.BeforeReceivedQty) FROM RECEIPTDETAIL RD3 (NOLOCK) WHERE RD3.ReceiptKey = @c_Receiptkey and RD3.ReceiptLineNumber = RECEIPTDETAIL.ReceiptLineNumber) BeforeReceivedQty, 
          RECEIPTDETAIL.TOID,
          RECEIPT.POKey,  
          SKU.DESCR,   
          SKU.Lottable01Label,
          SKU.Lottable02Label,
          SKU.Lottable03Label,
          CASE WHEN ISNULL(CLR.Code,'') <> '' THEN
               CLR.Description ELSE SKU.Lottable04Label END AS Lottable04Label,
          SKU.Lottable05Label,
          PACK.CaseCnt,   
          PACK.Qty,   
          PACK.PalletTI,   
          PACK.PalletHI, 
          PACK.PackDescr,
          LOC.Putawayzone, 
          Sku.Putawayzone,
          LOC.Facility,
          Loc_b.Putawayzone, 
          (SELECT COUNT( DISTINCT RD1.Lottable01) FROM RECEIPTDETAIL RD1 (NOLOCK) WHERE RD1.ReceiptKey = @c_Receiptkey and RD1.ReceiptLineNumber = RECEIPTDETAIL.ReceiptLineNumber) NoOfCases,
          CASE 
             WHEN RECEIPTDETAIL.UOM = PACK.PackUOM3 THEN PACK.Qty
             WHEN RECEIPTDETAIL.UOM = PACK.PackUOM1 THEN PACK.CaseCnt
             WHEN RECEIPTDETAIL.UOM = PACK.PackUOM2 THEN PACK.Innerpack
             WHEN RECEIPTDETAIL.UOM = PACK.PackUOM4 THEN PACK.Pallet
             WHEN RECEIPTDETAIL.UOM = PACK.PackUOM5 THEN PACK.Cube
             WHEN RECEIPTDETAIL.UOM = PACK.PackUOM6 THEN PACK.Grosswgt
             WHEN RECEIPTDETAIL.UOM = PACK.PackUOM7 THEN PACK.Netwgt
             WHEN RECEIPTDETAIL.UOM = PACK.PackUOM8 THEN PACK.OtherUnit1
             WHEN RECEIPTDETAIL.UOM = PACK.PackUOM5 THEN PACK.OtherUnit2
             ELSE 0
          END AS PACKQTY,
          RECEIPTDETAIL.UOM,
          CLR3.Description AS OWNER_Descr,
          CASE WHEN ISNULL(CLR2.Code,'') <> '' THEN 'Y' ELSE 'N' END AS MultiOwner,
          RECEIPT.ContainerKey,
          RECEIPTDETAIL.Lottable06,
          SKU.Lottable06Label,
          CONVERT(NVARCHAR,RECEIPTDETAIL.EditDate,103) AS EditDate
   FROM RECEIPTDETAIL (NOLOCK)    
   JOIN RECEIPT (NOLOCK) ON RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey  
   JOIN SKU (NOLOCK) ON SKU.StorerKey = RECEIPTDETAIL.StorerKey AND SKU.Sku = RECEIPTDETAIL.Sku
   LEFT JOIN LOC (NOLOCK) ON RECEIPTDETAIL.ToLoc = LOC.LOC
   LEFT JOIN LOC LOC_b (NOLOCK) ON RECEIPTDETAIL.PutawayLoc = LOC_b.LOC  
   LEFT JOIN Codelkup CLR (NOLOCK) ON (RECEIPTDETAIL.Storerkey = CLR.Storerkey AND CLR.Code = 'LOT04Label' 
                                   AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_receivinglabel25_rdt' AND ISNULL(CLR.Short,'') <> 'N')
   LEFT JOIN Codelkup CLR2 (NOLOCK) ON (RECEIPTDETAIL.Storerkey = CLR2.Storerkey AND CLR2.Code = 'MultiOwner' 
                                   AND CLR2.Listname = 'REPORTCFG' AND CLR2.Long = 'r_dw_receivinglabel25_rdt' AND ISNULL(CLR2.Short,'') <> 'N')
   LEFT JOIN Codelkup CLR3 (NOLOCK) ON (CLR3.Listname = 'SINOWNER' AND LOC.HostWHCode = CLR3.Code AND CLR3.Storerkey = RECEIPTDETAIL.Storerkey)
   JOIN PACK (NOLOCK) ON SKU.PACKKey = PACK.PackKey 
   JOIN #TMP_RECEIPT TR ON RECEIPTDETAIL.Receiptkey = TR.ReceiptKey 
                       AND RECEIPTDETAIL.ReceiptLineNumber BETWEEN TR.ReceiptLineNumberStart AND TR.ReceiptLineNumberEnd
   
   IF OBJECT_ID('tempdb..#TMP_RECEIPT') IS NOT NULL
      DROP TABLE #TMP_RECEIPT
END

GO