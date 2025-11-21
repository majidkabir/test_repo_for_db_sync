SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Store Procedure: isp_Receiving_Label_05_rdt                             */
/* Creation Date: 29-Mar-2021                                              */
/* Copyright: LFL                                                          */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose: WMS-16533 - RC - Create Datawindows report                     */
/*          Copy from isp_Receiving_Label_05                               */
/*                                                                         */
/* Called By: PB: r_dw_receivinglabel05_rdt                                */
/*                                                                         */
/* GitLab Version: 1.1                                                     */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author    Ver.  Purposes                                   */
/* 2021-04-28   WLChooi   1.1   WMS-16533 - Add ExternPOKey (WL01)         */
/* 2023-05-23   CSCHONG   1.2   WMS-22518 revised field format (CS01)      */
/* 2023-06-22   CSCHONG   1.3   WMS-22518 revised field format (CS02)      */
/***************************************************************************/
CREATE   PROC [dbo].[isp_Receiving_Label_05_rdt]
         @c_ReceiptKey        NVARCHAR(10)
       , @c_ToID              NVARCHAR(18)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SELECT RECEIPTDETAIL.ReceiptKey,
          RECEIPTDETAIL.ReceiptLineNumber,
          RECEIPTDETAIL.StorerKey,
          CASE WHEN ISNULL(CLR2.Code,'') <> '' THEN SKU.AltSku ELSE RECEIPTDETAIL.Sku END AS RECEIPTDETAIL_SKU,
          RECEIPTDETAIL.ToLoc,
          ISNULL(RECEIPTDETAIL.PutawayLoc,'') AS PutawayLoc,
          RECEIPTDETAIL.Lottable01,
          CASE WHEN ISNULL(CLR6.Short,'N') ='Y' THEN '' ELSE RECEIPTDETAIL.Lottable02 END AS Lottable02,
          CASE WHEN ISNULL(CLR6.Short,'N') ='Y' THEN '' ELSE RECEIPTDETAIL.Lottable03 END AS Lottable03,
          CASE WHEN ISNULL(CLR6.Short,'N') ='Y' THEN '' ELSE CONVERT(NVARCHAR(10),RECEIPTDETAIL.Lottable04,103) END AS Lottable04,
          CASE WHEN ISNULL(CLR6.Short,'N') ='Y' THEN '' ELSE CONVERT(NVARCHAR(10),RECEIPTDETAIL.Lottable05,103) END AS Lottable05,
          (SELECT SUM( RD1.QtyExpected) FROM RECEIPTDETAIL RD1 (NOLOCK) WHERE RD1.ReceiptKey = @c_Receiptkey and RD1.ReceiptLineNumber = RECEIPTDETAIL.ReceiptLineNumber) QtyExpected,
          (SELECT SUM( RD2.QtyReceived) FROM RECEIPTDETAIL RD2 (NOLOCK) WHERE RD2.ReceiptKey = @c_Receiptkey and RD2.ReceiptLineNumber = RECEIPTDETAIL.ReceiptLineNumber) QtyReceived,
          (SELECT SUM( RD3.BeforeReceivedQty) FROM RECEIPTDETAIL RD3 (NOLOCK) WHERE RD3.ReceiptKey = @c_Receiptkey and RD3.ReceiptLineNumber = RECEIPTDETAIL.ReceiptLineNumber) BeforeReceivedQty,
          RECEIPTDETAIL.TOID,
          RECEIPTDETAIL.POKey,
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
          Loc.Putawayzone,
          Sku.Putawayzone,
          LOC.Facility,
          Loc_b.Putawayzone,
          (SELECT COUNT( DISTINCT RD1.Lottable01) FROM RECEIPTDETAIL RD1 (NOLOCK) WHERE RD1.ReceiptKey = @c_Receiptkey and RD1.ReceiptLineNumber = RECEIPTDETAIL.ReceiptLineNumber) NoOfCases,
          CASE
            WHEN RECEIPTDETAIL.UOM = PACK.PackUOM3 THEN PACK.Qty
            WHEN RECEIPTDETAIL.UOM = PACK.PackUOM1 THEN PACK.CaseCnt
            WHEN RECEIPTDETAIL.UOM = PACK.PackUOM2 THEN PACK.Innerpack
            WHEN RECEIPTDETAIL.UOM = PACK.PackUOM4 THEN PACK.Pallet
            WHEN RECEIPTDETAIL.UOM = PACK.PackUOM5 THEN PACK.[Cube]
            WHEN RECEIPTDETAIL.UOM = PACK.PackUOM6 THEN PACK.Grosswgt
            WHEN RECEIPTDETAIL.UOM = PACK.PackUOM7 THEN PACK.Netwgt
            WHEN RECEIPTDETAIL.UOM = PACK.PackUOM8 THEN PACK.OtherUnit1
            WHEN RECEIPTDETAIL.UOM = PACK.PackUOM5 THEN PACK.OtherUnit2
            ELSE 0
          END AS PACKQTY,
          RECEIPTDETAIL.UOM,
          CLR3.Description AS OWNER_Descr,
          CASE WHEN ISNULL(CLR2.Code,'') <> '' THEN 'Y' ELSE 'N' END AS multiowner,
          CASE WHEN ISNULL(CLR4.Code,'') <> '' THEN 'Y' ELSE 'N' END AS showbarcode,
          ISNULL(CLR5.Short,'N') AS ShowLott06,
          RECEIPTDETAIL.Lottable06,
          SKU.LOTTABLE06LABEL,
          (SELECT MAX(ExternPOKey) FROM PO (NOLOCK) WHERE POKey = RECEIPTDETAIL.POKey) AS ExternPOKey,   --WL01
          ISNULL(CLR6.Short,'N') AS ShowLott040506,     --CS01 S
          CASE WHEN ISNULL(CLR6.Short,'N') ='N' THEN '' ELSE CONVERT(NVARCHAR(10),RECEIPTDETAIL.Lottable04,103) END AS Lott04,
          CASE WHEN ISNULL(CLR6.Short,'N') ='N' THEN '' ELSE CONVERT(NVARCHAR(10),RECEIPTDETAIL.Lottable05,103) END AS Lott05,
          CASE WHEN ISNULL(CLR6.Short,'N') ='N' THEN '' ELSE RECEIPTDETAIL.Lottable06 END AS Lott06,       --CS01 E
          CASE WHEN ISNULL(CLR6.Short,'N') ='N' THEN '' ELSE RECEIPTDETAIL.Lottable02 END AS Lott02,       --CS02
          CASE WHEN ISNULL(CLR6.Short,'N') ='N' THEN '' ELSE RECEIPTDETAIL.Lottable03 END AS Lott03        --CS02  
   FROM RECEIPTDETAIL (NOLOCK)
   JOIN SKU (NOLOCK) ON SKU.StorerKey = RECEIPTDETAIL.StorerKey
                    AND SKU.Sku = RECEIPTDETAIL.Sku
   LEFT JOIN LOC (NOLOCK) ON RECEIPTDETAIL.ToLoc = LOC.Loc
   LEFT JOIN LOC LOC_b (NOLOCK) ON RECEIPTDETAIL.PutawayLoc = LOC_b.Loc
   LEFT JOIN Codelkup CLR (NOLOCK) ON (RECEIPTDETAIL.Storerkey = CLR.Storerkey AND CLR.Code = 'LOT04Label'
                                   AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_receivinglabel05_rdt' AND ISNULL(CLR.Short,'') <> 'N')
   LEFT JOIN Codelkup CLR2 (NOLOCK) ON (RECEIPTDETAIL.Storerkey = CLR2.Storerkey AND CLR2.Code = 'MultiOwner'
                                    AND CLR2.Listname = 'REPORTCFG' AND CLR2.Long = 'r_dw_receivinglabel05_rdt' AND ISNULL(CLR2.Short,'') <> 'N')
   LEFT JOIN Codelkup CLR3 (NOLOCK) ON (CLR3.Listname = 'SINOWNER' AND LOC.HostWHCode = CLR3.Code AND CLR3.Storerkey = RECEIPTDETAIL.Storerkey)
   LEFT JOIN Codelkup CLR4 (NOLOCK) ON (RECEIPTDETAIL.Storerkey = CLR4.Storerkey AND CLR4.Code = 'ShowBarcode'
                                    AND CLR4.Listname = 'REPORTCFG' AND CLR4.Long = 'r_dw_receivinglabel05_rdt' AND ISNULL(CLR4.Short,'') <> 'N')
   LEFT JOIN Codelkup CLR5 (NOLOCK) ON (RECEIPTDETAIL.Storerkey = CLR5.Storerkey AND CLR5.Code = 'ShowLott06'
                                    AND CLR5.Listname = 'REPORTCFG' AND CLR5.Long = 'r_dw_receivinglabel05_rdt' AND ISNULL(CLR5.Short,'') <> 'N')
   LEFT JOIN Codelkup CLR6 (NOLOCK) ON (RECEIPTDETAIL.Storerkey = CLR6.Storerkey AND CLR6.Code = 'palletbarcodelottable'                              --CS01
                                    AND CLR6.Listname = 'REPORTCFG' AND CLR6.Long = 'r_dw_receivinglabel05_rdt' AND ISNULL(CLR6.Short,'') <> 'N')
   JOIN PACK (NOLOCK) ON SKU.PACKKey = PACK.PackKey
   WHERE ( RECEIPTDETAIL.ReceiptKey = @c_ReceiptKey ) AND
         ( RECEIPTDETAIL.ToID = @c_ToID)

END

GO