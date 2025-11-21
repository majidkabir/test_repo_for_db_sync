SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store Procedure: isp_Receiving_Label_05                                 */
/* Creation Date: 23-DEC-2022                                              */
/* Copyright: LF                                                           */
/* Written by: Mingle                                                      */
/*                                                                         */
/* Purpose:  Move Select statement to SP                                   */
/* Called By: PB: r_dw_receivinglabel05                                    */
/*                                                                         */
/* PVCS Version: 1.1                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author    Ver.  Purposes                                   */
/* 21-Dec-2022  Mingle    1.0   DevOps Combine Script(WMS-21336 - Created) */ 
/***************************************************************************/
CREATE PROC [dbo].[isp_Receiving_Label_05]
         @c_ReceiptKey         NVARCHAR(10) 
        ,@c_receiptline_from  NVARCHAR(5)
        ,@c_receiptline_to    NVARCHAR(5)

AS
BEGIN 
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @c_Storerkey       NVARCHAR(15)
         , @c_CarrierName     NVARCHAR(30)
         , @c_CustLot2Label   NVARCHAR(60)
         , @c_CustLot3Label   NVARCHAR(60)


   SET @c_Storerkey = ''
   SET @c_CarrierName = ''
   SET @c_CustLot2Label = ''
   SET @c_CustLot3Label = ''

			SELECT 
			RECEIPTDETAIL.ReceiptKey,  
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
         (SELECT SUM( RD1.QtyExpected) FROM RECEIPTDETAIL RD1 (NOLOCK) WHERE RD1.ReceiptKey = @c_receiptkey and RD1.ReceiptLineNumber = RECEIPTDETAIL.ReceiptLineNumber) QtyExpected, 
         (SELECT SUM( RD2.QtyReceived) FROM RECEIPTDETAIL RD2 (NOLOCK) WHERE RD2.ReceiptKey = @c_receiptkey and RD2.ReceiptLineNumber = RECEIPTDETAIL.ReceiptLineNumber) QtyReceived, 
         (SELECT SUM( RD3.BeforeReceivedQty) FROM RECEIPTDETAIL RD3 (NOLOCK) WHERE RD3.ReceiptKey = @c_receiptkey and RD3.ReceiptLineNumber = RECEIPTDETAIL.ReceiptLineNumber) BeforeReceivedQty, 
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
         (SELECT COUNT( DISTINCT RD1.Lottable01) FROM RECEIPTDETAIL RD1 (NOLOCK) WHERE RD1.ReceiptKey = @c_receiptkey and RD1.ReceiptLineNumber = RECEIPTDETAIL.ReceiptLineNumber) NoOfCases,
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
         CASE WHEN ISNULL(CLR2.Code,'') <> '' THEN 'Y' ELSE 'N' END AS multiowner ,
         CASE WHEN ISNULL(CLR4.Code,'') <> '' THEN 'Y' ELSE 'N' END AS showbarcode,
			--SKU.Lottable07Label,
			receiptdetail.lottable07,
			ISNULL(CLR5.SHORT,'') AS RepPLTbyLot07
			FROM RECEIPTDETAIL (NOLOCK)    
         JOIN SKU (NOLOCK) ON SKU.StorerKey = RECEIPTDETAIL.StorerKey 
                              AND SKU.Sku = RECEIPTDETAIL.Sku
         LEFT JOIN LOC (NOLOCK) ON RECEIPTDETAIL.ToLoc = LOC.Loc
			LEFT JOIN LOC LOC_b (NOLOCK) ON RECEIPTDETAIL.PutawayLoc = LOC_b.Loc  
         LEFT JOIN Codelkup CLR (NOLOCK) ON (RECEIPTDETAIL.Storerkey = CLR.Storerkey AND CLR.Code = 'LOT04Label' 
                                          AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_receivinglabel05' AND ISNULL(CLR.Short,'') <> 'N')
         LEFT JOIN Codelkup CLR2 (NOLOCK) ON (RECEIPTDETAIL.Storerkey = CLR2.Storerkey AND CLR2.Code = 'MultiOwner' 
                                          AND CLR2.Listname = 'REPORTCFG' AND CLR2.Long = 'r_dw_receivinglabel05' AND ISNULL(CLR2.Short,'') <> 'N')
         LEFT JOIN Codelkup CLR3 (NOLOCK) ON (CLR3.Listname = 'SINOWNER' AND LOC.HostWHCode = CLR3.Code AND CLR3.Storerkey = RECEIPTDETAIL.Storerkey)
         LEFT JOIN Codelkup CLR4 (NOLOCK) ON (RECEIPTDETAIL.Storerkey = CLR4.Storerkey AND CLR4.Code = 'ShowBarcode' 
                                          AND CLR4.Listname = 'REPORTCFG' AND CLR4.Long = 'r_dw_receivinglabel05' AND ISNULL(CLR4.Short,'') <> 'N')
         JOIN PACK (NOLOCK) ON SKU.PACKKey = PACK.PackKey
			LEFT JOIN CODELKUP CLR5 (NOLOCK) ON CLR5.LISTNAME = 'REPORTCFG' AND CLR5.Code = 'RepPLTbyLot07' 
												      AND CLR5.Long = 'r_dw_receivinglabel05' AND CLR5.Storerkey = RECEIPTDETAIL.StorerKey
			WHERE ( RECEIPTDETAIL.ReceiptKey = @c_receiptkey ) and
         ( RECEIPTDETAIL.ReceiptLineNumber BETWEEN @c_receiptline_from AND @c_receiptline_to )

END

SET QUOTED_IDENTIFIER OFF 

GO