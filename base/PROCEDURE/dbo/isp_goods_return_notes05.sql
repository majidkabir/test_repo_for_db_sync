SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_goods_return_notes05                           */
/* Creation Date: 07-Dec-2021                                           */
/* Copyright: IDS                                                       */
/* Written by: CHONG                                                    */
/*                                                                      */
/* Purpose: WMS-18498 SG - iDSMedû GRN [CR]                             */
/*                                                                      */
/* Called By: r_goods_return_notes05 (copy from goods_return_notes)     */
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 10-Dec-2021  CHONGCS   1.0   DevOps Combine Script                   */ 
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_goods_return_notes05]
 @c_ReceiptKeystart       NVARCHAR(20) ,
 @c_receiptkeyend         NVARCHAR(20)  = '',
 @c_storerkey             NVARCHAR(20) = ''

AS
BEGIN
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF  


    SELECT STORER.Company,   
         RECEIPT.ReceiptKey,   
         RECEIPT.CarrierReference,   
         RECEIPT.StorerKey,   
         RECEIPT.CarrierName,   
         RECEIPT.AddWho,   
         RECEIPT.ReceiptDate,   
         RECEIPTDETAIL.Sku,   
         RECEIPTDETAIL.Lottable02,   
         SKU.DESCR,   
         RECEIPTDETAIL.Lottable04,   
         RECEIPTDETAIL.UOM,   
         QtyRecv = SUM(RECEIPTDETAIL.QtyReceived),   
         SKU.STDCUBE, 
         RHNotes= CONVERT(NVARCHAR(60), RECEIPT.NOTES), 
         RECEIPT.CarrierAddress1, 
         RECEIPT.POkey, 
         RECEIPT.ExternReceiptKey, 
         RECEIPTDETAIL.Lottable03, 
         PACK.PACKUOM1, 
         PACK.CASECNT, 
         ConditionCode = ISNULL(CL.Description, RECEIPTDETAIL.ConditionCode)  ,
         SellerCompany = RECEIPT.SellerCompany,
         RDLott06 = RECEIPTDETAIL.Lottable06,
         RDLott08 = RECEIPTDETAIL.Lottable08,
         RDLott10 = RECEIPTDETAIL.Lottable10,
         RDLott12 = RECEIPTDETAIL.Lottable12,
         RDLott07 = RECEIPTDETAIL.Lottable07      
    FROM RECEIPT (NOLOCK)   
    JOIN RECEIPTDETAIL (NOLOCK) ON ( RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey )   
    JOIN STORER (NOLOCK) ON ( RECEIPTDETAIL.StorerKey = STORER.StorerKey )   
    JOIN SKU (NOLOCK) ON ( SKU.StorerKey = STORER.StorerKey AND SKU.StorerKey = RECEIPTDETAIL.StorerKey 
                        AND SKU.Sku = RECEIPTDETAIL.Sku ) 
    JOIN PACK (NOLOCK) ON ( SKU.PACKKEY = PACK.PACKKEY ) 
    LEFT OUTER JOIN (SELECT Code, Description FROM CODELKUP WITH (NOLOCK) WHERE (LISTNAME = 'ASNREASON' AND Storerkey = Storerkey)
                     UNION
                     SELECT Code, Description FROM CODELKUP WITH (NOLOCK) WHERE (LISTNAME = 'ASNREASON' AND Storerkey = '')
                     AND NOT EXISTS (SELECT 1 FROM CODELKUP WITH (NOLOCK) WHERE (LISTNAME = 'ASNREASON' AND Storerkey = Storerkey))
                     )CL ON (RECEIPTDETAIL.ConditionCode = CL.CODE)     
   WHERE ( RECEIPT.ReceiptKey >= @c_ReceiptKeyStart ) AND  
         ( REceipt.receiptkey <= @c_ReceiptkeyEnd ) AND 
         ( RECEIPT.Storerkey = @c_storerkey ) AND 
         ( RECEIPT.RECType <> 'NORMAL' )  
   GROUP BY STORER.Company,   
         RECEIPT.ReceiptKey,   
         RECEIPT.CarrierReference,   
         RECEIPT.StorerKey,   
         RECEIPT.CarrierName,   
         RECEIPT.AddWho,   
         RECEIPT.ReceiptDate,   
         RECEIPTDETAIL.Sku,   
         RECEIPTDETAIL.Lottable02,   
         SKU.DESCR,   
         RECEIPTDETAIL.Lottable04,   
         RECEIPTDETAIL.UOM,   
         SKU.STDCUBE, 
         CONVERT(NVARCHAR(60), RECEIPT.NOTES), 
         RECEIPT.CarrierAddress1, 
         RECEIPT.POkey, 
         RECEIPT.ExternReceiptKey, 
         RECEIPTDETAIL.Lottable03, 
         PACK.PACKUOM1, 
         PACK.CASECNT, 
         ISNULL(CL.Description, RECEIPTDETAIL.ConditionCode) ,
         RECEIPT.SellerCompany,RECEIPTDETAIL.Lottable06,RECEIPTDETAIL.Lottable08, 
         RECEIPTDETAIL.Lottable10,RECEIPTDETAIL.Lottable12,RECEIPTDETAIL.Lottable07
   
   
  
END

GO