SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 
/************************************************************************/    
/* Stored Proc: isp_ReceiptPreTallySheet07                              */    
/* Creation Date: 17-Sep-2019                                           */    
/* Copyright: LF Logistics                                              */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose: WMS-10604 - NIKE_PH_WMS_PreTallySheet                       */     
/*        :                                                             */    
/* Called By: r_receipt_pre_tallysheet07                                */  
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
  
CREATE PROC [dbo].[isp_ReceiptPreTallySheet07]    
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
           , @n_StartTCnt INT = @@TRANCOUNT,@n_ttlcases int = 0
         
         select @n_ttlcases = count(distinct RECEIPTDETAIL.Lottable10)        
    FROM RECEIPT (NOLOCK)  
    JOIN RECEIPTDETAIL (NOLOCK) ON RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey  
    JOIN SKU (NOLOCK) ON SKU.StorerKey = RECEIPTDETAIL.StorerKey AND SKU.Sku = RECEIPTDETAIL.Sku   
    JOIN STORER (NOLOCK) ON RECEIPT.Storerkey = STORER.Storerkey  
    WHERE ( RECEIPT.ReceiptKey >= @c_ReceiptStart ) AND    
         ( RECEIPT.ReceiptKey <= @c_ReceiptEnd   ) AND    
         ( RECEIPT.Storerkey  >= @c_StorerStart  ) AND   
         ( RECEIPT.Storerkey  <= @c_StorerEnd    )   

     
   SELECT Receiptkey = RECEIPT.ReceiptKey,     
          ExternPOKey = RECEIPTDETAIL.ExternPOKey,     
          Sku = RECEIPTDETAIL.Sku,    
          QtyExpected =SUM(RECEIPTDETAIL.QtyExpected),  
          username = SUSER_NAME(),     
          --RECEIPT.ExternReceiptkey,    
          Lottable01 = RECEIPTDETAIL.Lottable01 ,  
          Lottable10 = RECEIPTDETAIL.Lottable10,
          ST_Company = STORER.Company ,
          ttlcases = @n_ttlcases        
    FROM RECEIPT (NOLOCK)  
    JOIN RECEIPTDETAIL (NOLOCK) ON RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey  
    JOIN SKU (NOLOCK) ON SKU.StorerKey = RECEIPTDETAIL.StorerKey AND SKU.Sku = RECEIPTDETAIL.Sku   
    JOIN STORER (NOLOCK) ON RECEIPT.Storerkey = STORER.Storerkey  
    WHERE ( RECEIPT.ReceiptKey >= @c_ReceiptStart ) AND    
         ( RECEIPT.ReceiptKey <= @c_ReceiptEnd   ) AND    
         ( RECEIPT.Storerkey  >= @c_StorerStart  ) AND   
         ( RECEIPT.Storerkey  <= @c_StorerEnd    )   
    GROUP BY RECEIPT.ReceiptKey,     
             RECEIPTDETAIL.ExternPOKey,     
             RECEIPTDETAIL.Sku,      
             RECEIPTDETAIL.Lottable01,  
             RECEIPTDETAIL.Lottable10 ,
             STORER.Company
   ORDER BY RECEIPT.Receiptkey, RECEIPTDETAIL.Lottable01,RECEIPTDETAIL.Lottable10,RECEIPTDETAIL.Sku  
      
   IF CURSOR_STATUS('LOCAL' , 'cur_Loop') in (0 , 1)  
   BEGIN  
      CLOSE cur_Loop  
      DEALLOCATE cur_Loop     
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
    
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_ReceiptPreTallySheet07'    
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