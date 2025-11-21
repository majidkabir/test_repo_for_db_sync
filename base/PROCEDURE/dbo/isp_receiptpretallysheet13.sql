SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_ReceiptPreTallySheet13                              */  
/* Creation Date: 06-DEC-2021                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose: WMS-18415 - PH PNG Pre Tally Sheet-CR                       */   
/*        :                                                             */  
/* Called By: r_receipt_pre_tallysheet13                                */
/*          :                                                           */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver   Purposes                                */  
/* 06-Dec-2021  CSCHONG   1.0   Devops Scripts Combine                  */
/************************************************************************/ 

CREATE PROC [dbo].[isp_ReceiptPreTallySheet13]  
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
         RDUDF01 = RECEIPTDETAIL.userdefine01,   --30
         busr8 = sku.busr8,
         CSQty = CASE WHEN Receiptdetail.UOM = 'IT' Then (RECEIPTDETAIL.QTYEXPECTED/PACK.CASECNT) 
                 ELSE Receiptdetail.QtyExpected END,
         TixHI = CONCAT (PACK.PalletTI,'x',PACK.PalletHI),
         PltConfig = CASE WHEN  PACK.PACKUOM3 = 'IT' THEN (Pack.pallet / pack.casecnt) else Pack.pallet END 
    FROM RECEIPT (nolock) join RECEIPTDETAIL (nolock)
            on RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey
         join SKU (nolock)
            on SKU.StorerKey = RECEIPTDETAIL.StorerKey
               and SKU.Sku = RECEIPTDETAIL.Sku
         join STORER (nolock)
            on RECEIPT.Storerkey = STORER.Storerkey
         join PACK (nolock)
            on PACK.PackKey = RECEIPTDETAIL.PackKey
         left outer join CODELKUP (NOLOCK)
            on SKU.SUSR3 = CODELKUP.CODE
               and CODELKUP.LISTNAME = 'PRINCIPAL'
   join facility f (nolock) on f.facility = receipt.facility
   WHERE ( RECEIPT.ReceiptKey >= @c_ReceiptStart ) AND  
         ( RECEIPT.ReceiptKey <= @c_ReceiptEnd ) AND  
         ( RECEIPT.Storerkey >= @c_StorerStart ) AND 
         ( RECEIPT.Storerkey <= @c_StorerEnd ) 
   ORDER BY RECEIPT.ReceiptKey,receiptdetail.sku
  
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
  
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_ReceiptPreTallySheet13'  
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