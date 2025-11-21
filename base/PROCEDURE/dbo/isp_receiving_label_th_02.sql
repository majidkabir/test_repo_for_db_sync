SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store Procedure: isp_Receiving_Label_TH_02                              */
/* Creation Date: 30-Apr-2021                                              */
/* Copyright: LFL                                                          */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose: WMS-16931 - TH-IDSMED CR - PutawayLabel                        */
/*          Copy from r_dw_receivinglabel_TH                               */
/*                                                                         */
/* Called By: PB: r_dw_receivinglabel_TH_02                                */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author    Ver.  Purposes                                   */
/***************************************************************************/
CREATE PROC [dbo].[isp_Receiving_Label_TH_02]
         @c_ReceiptKey        NVARCHAR(10) 
       , @c_Receiptline_From  NVARCHAR(10)
       , @c_Receiptline_To    NVARCHAR(10)
AS
BEGIN 
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF  

   SELECT RECEIPTDETAIL.ReceiptKey,  
          RECEIPTDETAIL.ReceiptLineNumber,  
          RECEIPTDETAIL.StorerKey,   
          RECEIPTDETAIL.Sku,   
          RECEIPTDETAIL.ToLoc,   
          RECEIPTDETAIL.PutawayLoc,   
          RECEIPTDETAIL.Lottable01,   
          RECEIPTDETAIL.Lottable02,   
          RECEIPTDETAIL.Lottable03,   
          RECEIPTDETAIL.Lottable04,   
          RECEIPTDETAIL.Lottable05,   
          RECEIPTDETAIL.QtyExpected,   
          RECEIPTDETAIL.QtyReceived, 
          RECEIPTDETAIL.BeforeReceivedQty, 
          RECEIPTDETAIL.TOID,
          RECEIPTDETAIL.POKey,  
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
          RECEIPTDETAIL.Lottable12,
          RECEIPTDETAIL.Lottable08,
          RECEIPTDETAIL.Lottable09,
          RECEIPTDETAIL.Lottable10,
          RECEIPTDETAIL.Lottable11
   FROM RECEIPTDETAIL (NOLOCK)  
   JOIN SKU (NOLOCK) ON SKU.StorerKey = RECEIPTDETAIL.StorerKey AND SKU.Sku = RECEIPTDETAIL.Sku
   LEFT JOIN LOC (NOLOCK) ON RECEIPTDETAIL.ToLoc = LOC.Loc 
   JOIN PACK (NOLOCK) ON PACK.PackKey = SKU.PACKKey
   LEFT JOIN LOC LOC_b (NOLOCK) ON RECEIPTDETAIL.PutawayLoc = LOC_b.Loc
   WHERE ( RECEIPTDETAIL.ReceiptKey = @c_receiptkey ) and
         ( RECEIPTDETAIL.ReceiptLineNumber BETWEEN @c_receiptline_from AND @c_receiptline_to )

END

GO