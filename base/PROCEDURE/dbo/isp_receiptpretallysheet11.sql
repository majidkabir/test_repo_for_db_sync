SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_ReceiptPreTallySheet11                              */  
/* Creation Date: 20-JUL-2021                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose: WMS-17504 - PH_IDSMED PreTallySheet                         */   
/*        :                                                             */  
/* Called By: r_receipt_pre_tallysheet11                                */
/*          :                                                           */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */  
/************************************************************************/ 

CREATE PROC [dbo].[isp_ReceiptPreTallySheet11]  
            @c_ReceiptStart   NVARCHAR(10)  
         ,  @c_ReceiptEnd     NVARCHAR(10)  
         ,  @c_StorerStart    NVARCHAR(15)  
         ,  @c_StorerEnd      NVARCHAR(15) 
         ,  @c_userid         NVARCHAR(20) = ''
  
AS  
BEGIN   
   SET NOCOUNT ON        
   SET ANSI_NULLS OFF        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF    
   
   DECLARE @n_continue INT = 1, @n_err INT = 0, @c_errmsg NVARCHAR(255) = '', @b_Success INT = 1
         , @n_StartTCnt INT = @@TRANCOUNT, @c_GetReceiptKey NVARCHAR(10)
   
   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN
        SELECT RECEIPT.ReceiptKey,   
         RECEIPTDETAIL.ExternPOKey,   
         RECEIPTDETAIL.Sku,  
         PRINCIPAL= receipt.facility,
         PRINDESC=f.descr, 
         SKU.DESCR,   
         RECEIPTDETAIL.UOM,
         STORER.Company,   
         RECEIPT.ReceiptDate,    
         RECEIPTDETAIL.PackKey,   
         SKU.SUSR3,   
         RECEIPTDETAIL.QtyExpected,
         WarehouseReference = UPPER(RECEIPT.WarehouseReference),
         PACK.CaseCnt,
         PACK.Pallet,
         PACK.PackUOM3,
         RECEIPTDETAIL.FreeGoodQtyExpected,
         USERNAME = user_name(),
         PACK.PackUOM1,
         PACK.PackUOM2, 
         PACK.PackUOM4,
         Pack.Innerpack,
         ExternReceiptkey= UPPER(RECEIPT.ExternReceiptkey),  
         RECEIPTDETAIL.Lottable01,
         Lottable02 = UPPER(RECEIPTDETAIL.Lottable02),  
         RECEIPTDETAIL.Lottable03,  
         RECEIPTDETAIL.Lottable04,
         Lottable08 = UPPER(RECEIPTDETAIL.Lottable08),    
         Lottable10 = UPPER(RECEIPTDETAIL.Lottable10), 
         Lottable12 = UPPER(RECEIPTDETAIL.Lottable12),  
         SKU.IVAS
    FROM RECEIPT (nolock) 
    JOIN RECEIPTDETAIL (nolock)
            on RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey
    JOIN SKU (nolock)
            on SKU.StorerKey = RECEIPTDETAIL.StorerKey
               and SKU.Sku = RECEIPTDETAIL.Sku
    JOIN STORER (nolock)
            on RECEIPT.Storerkey = STORER.Storerkey
    JOIN PACK (nolock)
            on PACK.PackKey = SKU.PackKey
    LEFT outer join CODELKUP (NOLOCK)
            on SKU.SUSR3 = CODELKUP.CODE
               and CODELKUP.LISTNAME = 'PRINCIPAL'
   join facility f (nolock) on f.facility = receipt.facility
   WHERE ( RECEIPT.ReceiptKey >= @c_ReceiptStart ) AND  
         ( RECEIPT.ReceiptKey <= @c_ReceiptEnd ) AND  
         ( RECEIPT.Storerkey >= @c_StorerStart ) AND 
         ( RECEIPT.Storerkey <= @c_StorerEnd ) 
  
   END
   
   IF @n_Continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_Success = 0  
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_StartTCnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
  
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_ReceiptPreTallySheet11'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
   END  
   ELSE  
   BEGIN  
      SET @b_Success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
   END  
    
   WHILE @@TRANCOUNT < @n_StartTCnt   
      BEGIN TRAN;     
  
END

GO