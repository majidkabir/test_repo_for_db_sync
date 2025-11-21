SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Store Procedure: isp_Receiving_Label_27                                 */
/* Creation Date: 30-Sep-2022                                              */
/* Copyright: LFL                                                          */
/* Written by: Mingle                                                      */
/*                                                                         */
/* Purpose: WMS-20878 - RC - Create Datawindows report                     */
/*          Copy from isp_Receiving_Label_26                               */
/*                                                                         */
/* Called By: PB: r_dw_receivinglabel27                                    */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author    Ver.  Purposes                                   */
/* 30-Sep-2022  Mingle    1.0   DevOps Combine Script(Created)             */ 
/***************************************************************************/
CREATE PROC [dbo].[isp_Receiving_Label_27]
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
         ISNULL(RECEIPTDETAIL.PutawayLoc, '') as 'PutawayLoc',   
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
			ISNULL(Loc_b.Putawayzone, '') as 'Putawayzone',
			TD1.FinalLOC,
			TD1.ToLoc
    FROM RECEIPTDETAIL (NOLOCK)  
         JOIN SKU (NOLOCK) ON SKU.StorerKey = RECEIPTDETAIL.StorerKey AND SKU.Sku = RECEIPTDETAIL.Sku 
         LEFT JOIN LOC (NOLOCK) ON RECEIPTDETAIL.ToLoc = LOC.Loc 
         JOIN PACK (NOLOCK) ON PACK.PackKey = SKU.PACKKey
			LEFT JOIN TASKDETAIL TD1 (NOLOCK) ON TD1.FROMID = RECEIPTDETAIL.TOID AND TD1.TASKTYPE = 'ASTPA1'
			--LEFT JOIN TASKDETAIL TD2(NOLOCK) ON TD2.FROMID = RECEIPTDETAIL.TOID AND TD2.TASKTYPE = 'ASTPA1'
			--									     AND TD2.FINALLOC = LOC.LOC
			LEFT JOIN LOC LOC_b (NOLOCK) ON  RECEIPTDETAIL.PutawayLoc = LOC_b.Loc 
   WHERE ( ( RECEIPTDETAIL.ReceiptKey = @c_ReceiptKey ) and
			  ( RECEIPTDETAIL.ReceiptlineNumber >= @c_Receiptline_From ) AND 
           ( RECEIPTDETAIL.ReceiptLineNumber <= @c_Receiptline_To ) ) AND
			  (RECEIPTDETAIL.TOID <> '' )

END

GO