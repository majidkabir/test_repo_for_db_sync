SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Store Procedure: isp_Receiving_Label_TH                                 */
/* Creation Date: 21-Dec-2022                                              */
/* Copyright: LFL                                                          */
/* Written by: Mingle                                                      */
/*                                                                         */
/* Purpose: WMS-21336 - TH - ELANCORS - CR Receiving Pallet Label          */
/*                                                                         */
/* Called By: PB: r_dw_receivinglabel_TH                                   */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author    Ver.  Purposes                                   */
/* 21-Dec-2022  Mingle    1.0   DevOps Combine Script(WMS-21336 - Created) */  
/***************************************************************************/
CREATE PROC [dbo].[isp_Receiving_Label_TH]
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
			--SKU.Lottable07Label,
			receiptdetail.lottable07,
			ISNULL(CL.SHORT,'') AS RepPLTbyLot07
    FROM RECEIPTDETAIL (NOLOCK)  
         JOIN SKU (NOLOCK) ON SKU.StorerKey = RECEIPTDETAIL.StorerKey AND SKU.Sku = RECEIPTDETAIL.Sku
         LEFT JOIN LOC (NOLOCK) ON RECEIPTDETAIL.ToLoc = LOC.Loc 
         JOIN PACK (NOLOCK) ON PACK.PackKey = SKU.PACKKey
			LEFT JOIN LOC LOC_b (NOLOCK) ON RECEIPTDETAIL.PutawayLoc = LOC_b.Loc
			LEFT JOIN CODELKUP CL(NOLOCK) ON CL.LISTNAME = 'REPORTCFG' AND CL.Code = 'RepPLTbyLot07' 
												  AND CL.Long = 'r_dw_receivinglabel_TH' AND CL.Storerkey = RECEIPTDETAIL.StorerKey
   WHERE ( RECEIPTDETAIL.ReceiptKey = @c_receiptkey ) AND
         ( RECEIPTDETAIL.ReceiptLineNumber BETWEEN @c_receiptline_from AND @c_receiptline_to )

END

GO