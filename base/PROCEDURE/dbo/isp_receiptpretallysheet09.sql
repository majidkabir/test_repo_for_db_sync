SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_ReceiptPreTallySheet09                              */  
/* Creation Date: 20-MAY-2021                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose: WMS-17062 - PH_Young Living - PreTally Sheet                */   
/*        :                                                             */  
/* Called By: r_receipt_pre_tallysheet09                                */
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

CREATE PROC [dbo].[isp_ReceiptPreTallySheet09]  
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
      SELECT R.Receiptkey
           , R.ReceiptDate
           , R.POKey
           , R.StorerKey
           , R.Facility
           , R.ExternReceiptKey
           , RD.Sku
           , S.DESCR
           , RD.UOM
           , SUM(RD.QtyExpected) AS QtyExpected
           , S.Style
           , ISNULL(PODET.UserDefine02,'') AS PODUserDefine02   
           ,RD.Lottable02
           ,RD.Lottable04 AS ExpDate
           ,RD.Lottable13 AS MfgDate
      FROM RECEIPT R (NOLOCK)
      JOIN RECEIPTDETAIL RD (NOLOCK)ON R.ReceiptKey = RD.ReceiptKey
      JOIN SKU S (NOLOCK) ON S.StorerKey = R.StorerKey AND S.Sku = RD.Sku
      OUTER APPLY (SELECT TOP 1 P.UserDefine02 
                   FROM PODETAIL P (NOLOCK)
                   WHERE P.POKey = RD.POKey AND P.Storerkey = RD.Storerkey AND P.SKU = RD.SKU) AS PODET  
      WHERE R.StorerKey BETWEEN @c_StorerStart AND @c_StorerEnd
      AND R.ReceiptKey BETWEEN @c_ReceiptStart AND @c_ReceiptEnd
      GROUP BY R.Receiptkey
             , R.ReceiptDate
             , R.POKey
             , R.StorerKey
             , R.Facility
             , R.ExternReceiptKey
             , RD.Sku
             , S.DESCR
             , RD.UOM
             , S.Style
             , ISNULL(PODET.UserDefine02,'')  
             ,RD.Lottable02
             ,RD.Lottable04
             ,RD.Lottable13
      ORDER BY R.ReceiptKey, ISNULL(PODET.UserDefine02,''), S.Style, RD.Sku   
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
  
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_ReceiptPreTallySheet09'  
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