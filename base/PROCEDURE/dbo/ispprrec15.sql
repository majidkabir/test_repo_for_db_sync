SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/  
/* Stored Procedure: ispPRREC15                                            */  
/* Creation Date: 10-SEP-2020                                              */  
/* Copyright: LFL                                                          */  
/* Written by:  CSCHONG                                                    */  
/*                                                                         */  
/* Purpose: WMS-15003 - CMGMY Trade Return to stamp lottable01 lottable02  */  
/*                                                                         */  
/* Called By:                                                              */  
/*                                                                         */  
/*                                                                         */  
/* PVCS Version: 1.0                                                       */  
/*                                                                         */  
/* Version: 7.0                                                            */  
/*                                                                         */  
/* Data Modifications:                                                     */  
/*                                                                         */  
/* Updates:                                                                */  
/* Date         Author  Ver   Purposes                                     */  
/***************************************************************************/    
CREATE PROC [dbo].[ispPRREC15]    
(     @c_Receiptkey         NVARCHAR(10)    
  ,   @c_ReceiptLineNumber  NVARCHAR(5) = ''        
  ,   @b_Success            INT           OUTPUT  
  ,   @n_Err                INT           OUTPUT  
  ,   @c_ErrMsg             NVARCHAR(255) OUTPUT     
)    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @b_Debug              INT  
         , @n_Cnt                INT  
         , @n_Continue           INT   
         , @n_StartTranCount     INT   
         , @c_Lottable01         NVARCHAR(18) = '' 
         , @c_Lottable02         NVARCHAR(18) = ''
         , @c_SKU                NVARCHAR(20) = ''
         , @c_Storerkey          NVARCHAR(15) = ''
         , @c_Sbusr1             NVARCHAR(50) = ''
         , @c_RecType            NVARCHAR(10) = ''

   SET @b_Success= 1   
   SET @n_Err    = 0    
   SET @c_ErrMsg = ''  
   SET @b_Debug = 0   
   SET @n_Continue = 1    
   SET @n_StartTranCount = @@TRANCOUNT    
     
   DECLARE CUR_RD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
   SELECT RD.ReceiptLineNumber, RD.SKU, RD.Storerkey,RH.rectype
   FROM RECEIPTDETAIL RD (NOLOCK) --WL01
   JOIN RECEIPT RH (NOLOCK) ON RH.RECEIPTKEY = RD.RECEIPTKEY AND RH.STORERKEY = RD.STORERKEY
   WHERE RD.RECEIPTKEY = @c_Receiptkey 
   AND   RD.ReceiptLineNumber = CASE WHEN ISNULL(RTRIM(@c_ReceiptLineNumber),'') = '' THEN RD.ReceiptLineNumber ELSE @c_ReceiptLineNumber END  
   AND   RH.receiptgroup = 'STR'

   OPEN CUR_RD  
  
   FETCH NEXT FROM CUR_RD INTO @c_ReceiptLineNumber, @c_SKU, @c_Storerkey,@c_RecType  
                           
   WHILE @@FETCH_STATUS <> -1   
   BEGIN

     SET @c_Sbusr1 = ''
     SET @c_Lottable01 = ''
     SET @c_Lottable02 = ''

     SELECT @c_Sbusr1 = S.busr1
     FROM SKU S WITH (NOLOCK)
     WHERE S.storerkey = @c_Storerkey
     AND S.sku = @c_SKU 
 
      SELECT @c_Lottable01 = c.udf02
            ,@c_Lottable02 = c.udf03
      FROM  codelkup c WITH (NOLOCK) 
      where c.listname = 'CMGDIV'
      and c.code = @c_Sbusr1
      and c.storerkey = @c_Storerkey
      and c.UDF01 = @c_RecType

      --IF(ISNULL(@c_Lottable01,'') = '') OR IF(ISNULL(@c_Lottable02,'') = '')
      --BEGIN   
      --   SET @n_continue = 3    
      --   SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
      --   SET @n_err = 82000      
      --   SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Cannot Find Current Stock Balance with SKU: ' + @c_SKU + ' (ispPRREC13)'   
      --             + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '    
      --   GOTO QUIT_SP  
      --END

      IF(@b_Debug = 1)
         SELECT @c_SKU, @c_Lottable02

      UPDATE RECEIPTDETAIL WITH (ROWLOCK)
      SET LOTTABLE01 = @c_Lottable01 
       , LOTTABLE02 = @c_Lottable02
      WHERE RECEIPTKEY = @c_Receiptkey AND RECEIPTLINENUMBER = @c_ReceiptLineNumber
      
      SET @n_err = @@ERROR    
     
      IF @n_err <> 0     
      BEGIN    
         SET @n_continue = 3    
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
         SET @n_err = 82005     
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update RECEIPTDETAIL Table Failed. (ispPRREC15)'   
                      + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '    
         GOTO QUIT_SP  
      END   
   FETCH NEXT FROM CUR_RD INTO @c_ReceiptLineNumber, @c_SKU, @c_Storerkey , @c_RecType
   END  
   CLOSE CUR_RD  
   DEALLOCATE CUR_RD  
  
   QUIT_SP:  
   IF @n_Continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_Success = 0  
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCount  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_StartTranCount  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
  
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPRREC15'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
   END  
   ELSE  
   BEGIN  
      SET @b_Success = 1  
      WHILE @@TRANCOUNT > @n_StartTranCount  
      BEGIN  
         COMMIT TRAN  
      END  
   END  
END  


GO