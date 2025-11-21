SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_ReceiptPreTallySheet05                              */  
/* Creation Date: 17-Sep-2019                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-10604 - NIKE_PH_WMS_PreTallySheet                       */   
/*        :                                                             */  
/* Called By: r_receipt_pre_tallysheet05                                */
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

CREATE PROC [dbo].[isp_ReceiptPreTallySheet05]  
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
           , @n_StartTCnt INT = @@TRANCOUNT, @c_GetReceiptKey NVARCHAR(10), @c_GetUserDefine03 NVARCHAR(30)
           , @c_GetUserDefine07 DATETIME

   CREATE TABLE #ITEMCLASS(
   RECEIPTKEY         NVARCHAR(10),
   PalletPosition     INT  )

   INSERT INTO #ITEMCLASS
   SELECT RECEIPT.RECEIPTKEY,
          COUNT(DISTINCT SKU.ITEMCLASS) + 4
   FROM RECEIPT (NOLOCK)
   JOIN RECEIPTDETAIL (NOLOCK) ON RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey
   JOIN SKU (NOLOCK) ON RECEIPTDETAIL.SKU = SKU.SKU AND RECEIPT.STORERKEY = SKU.STORERKEY
   WHERE ( RECEIPT.ReceiptKey >= @c_ReceiptStart ) AND  
         ( RECEIPT.ReceiptKey <= @c_ReceiptEnd   ) AND  
         ( RECEIPT.Storerkey  >= @c_StorerStart  ) AND 
         ( RECEIPT.Storerkey  <= @c_StorerEnd    ) 
   GROUP BY RECEIPT.RECEIPTKEY
   
   --SELECT * FROM #ITEMCLASS   
        
   SELECT RECEIPT.ReceiptKey,   
          RECEIPTDETAIL.ExternPOKey,   
          RECEIPTDETAIL.Sku,  
          PRINCIPAL = SKU.SUSR3,
          PRINDESC = CODELKUP.DESCRIPTION, 
          SKU.DESCR,   
          RECEIPTDETAIL.UOM,
          STORER.Company,   
          RECEIPT.ReceiptDate,    
          RECEIPTDETAIL.PackKey,   
          SKU.SUSR3,   
          RECEIPTDETAIL.QtyExpected,
          RECEIPT.WarehouseReference,
          PACK.CaseCnt,
          PACK.Pallet,
          PACK.PackUOM3,
          RECEIPTDETAIL.FreeGoodQtyExpected,
          SUSER_NAME(),
          PACK.PackUOM1,
          PACK.PackUOM2, 
          PACK.PackUOM4,
          Pack.Innerpack,
          RECEIPT.ExternReceiptkey,  
          RECEIPTDETAIL.Lottable01,
          RECEIPTDETAIL.Lottable02,  
          RECEIPTDETAIL.Lottable03,  
          RECEIPTDETAIL.Lottable04,
          t.PalletPosition 
    FROM RECEIPT (NOLOCK)
    JOIN RECEIPTDETAIL (NOLOCK) ON RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey
    JOIN SKU (NOLOCK) ON SKU.StorerKey = RECEIPTDETAIL.StorerKey AND SKU.Sku = RECEIPTDETAIL.Sku
    JOIN STORER (NOLOCK) ON RECEIPT.Storerkey = STORER.Storerkey
    JOIN PACK (NOLOCK) ON PACK.PackKey = SKU.PackKey
    LEFT OUTER JOIN CODELKUP (NOLOCK) ON SKU.SUSR3 = CODELKUP.CODE AND CODELKUP.LISTNAME = 'PRINCIPAL'
    JOIN #ITEMCLASS t ON t.ReceiptKey = RECEIPT.Receiptkey
    
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
  
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_ReceiptPreTallySheet05'  
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