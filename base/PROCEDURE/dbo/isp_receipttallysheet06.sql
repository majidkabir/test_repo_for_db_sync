SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_ReceiptTallySheet06                                 */  
/* Creation Date: 15-Jan-2021                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by:CSCHONG                                                   */  
/*                                                                      */  
/* Purpose: WMS-16070 PH_TallySheet_Modification                        */   
/*        :                                                             */  
/* Called By: r_receipt_tallysheet06                                    */
/*            convert from SQL to SP                                    */  
/*          :                                                           */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */  
/************************************************************************/ 

CREATE PROC [dbo].[isp_ReceiptTallySheet06]  
            @c_ReceiptKeyStart   NVARCHAR(10)  
         ,  @c_ReceiptKeyEnd     NVARCHAR(10)  
         ,  @c_StorerKeyStart    NVARCHAR(15)  
         ,  @c_StorerKeyEnd      NVARCHAR(15) 
         ,  @c_UserID            NVARCHAR(80) = ''
  
AS  
BEGIN   
   SET NOCOUNT ON        
   SET ANSI_NULLS OFF        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF 


    SELECT RECEIPT.ReceiptKey,   
         RECEIPTDETAIL.ExternPOKey,   
         RECEIPTDETAIL.Sku,   
         PRINCIPAL=SKU.SUSR3,
         PRINDESC=CODELKUP.DESCRIPTION,
         SKU.DESCR,   
         UPPER(RECEIPTDETAIL.UOM) AS UOM,   
         RECEIPTDETAIL.Lottable02,   
         RECEIPTDETAIL.Lottable04,   
         STORER.Company,    
         RECEIPT.ReceiptDate,   
         RECEIPTDETAIL.PackKey,   
         SKU.SUSR3,   
         RECEIPTDETAIL.QtyExpected , 
         RECEIPTDETAIL.BeforeReceivedQty,
         PACK.CaseCnt,
         PACK.Pallet,
         PACK.PackUOM3,
         RECEIPTDETAIL.FreeGoodQtyExpected,
         RECEIPTDETAIL.FreeGoodQtyReceived,
         user_name(),
         PACK.PackUOM1,
         PACK.PackUOM2,
         PACK.PackUOM4,
         PACK.Innerpack
    FROM RECEIPT (nolock) join RECEIPTDETAIL (nolock)
            on RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey
         join SKU (nolock)
            on SKU.StorerKey = RECEIPTDETAIL.StorerKey
               and SKU.Sku = RECEIPTDETAIL.Sku
         join STORER (nolock)
            on RECEIPT.Storerkey = STORER.Storerkey
         join PACK (nolock)
            on PACK.PackKey = SKU.PackKey
         left outer join CODELKUP (NOLOCK)
            on SKU.SUSR3 = CODELKUP.CODE
               and CODELKUP.LISTNAME = 'PRINCIPAL'
   WHERE ( RECEIPT.ReceiptKey >= @c_ReceiptKeyStart ) AND  
         ( RECEIPT.ReceiptKey <= @c_ReceiptKeyEnd ) AND  
         ( RECEIPT.Storerkey >=  @c_StorerKeyStart ) AND 
         ( RECEIPT.Storerkey <=  @c_StorerKeyEnd ) 
  ORDER BY RECEIPT.Storerkey,RECEIPT.ReceiptKey,RECEIPTDETAIL.Sku,RECEIPTDETAIL.Lottable02 , RECEIPTDETAIL.Lottable04 
  
END

GO