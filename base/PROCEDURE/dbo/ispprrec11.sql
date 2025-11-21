SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/  
/* Stored Procedure: ispPRREC11                                            */  
/* Creation Date: 18-OCT-2018                                              */  
/* Copyright: LFL                                                          */  
/* Written by:  WLCHOOI                                                    */  
/*                                                                         */  
/* Purpose: WMS-6766 CPV û PrePost Validation for Receipt                  */  
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
/*27-May-2019   WLCHOOI 1.1   Add NOLOCK (WL01)                            */
/*05-Aug-2019   WLCHOOI 1.2   Fixed compilation error (WL02)               */
/***************************************************************************/    
CREATE PROC [dbo].[ispPRREC11]    
(     @c_Receiptkey  NVARCHAR(10)    
  ,   @c_ReceiptLineNumber  NVARCHAR(5) = ''        
  ,   @b_Success     INT           OUTPUT  
  ,   @n_Err         INT           OUTPUT  
  ,   @c_ErrMsg      NVARCHAR(255) OUTPUT     
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
     
   SET @b_Success= 1   
   SET @n_Err    = 0    
   SET @c_ErrMsg = ''  
   SET @b_Debug = '0'   
   SET @n_Continue = 1    
   SET @n_StartTranCount = @@TRANCOUNT    
     
   --IF NOT EXISTS( SELECT 1  
   --               FROM RECEIPT WITH (NOLOCK)  
   --               WHERE ReceiptKey = @c_Receiptkey  
   --               AND DocType = 'A'   
   --               AND Userdefine04 = 'PO'  
   --             )  
   --BEGIN  
   --   GOTO QUIT_SP          
   --END  
       
   DECLARE CUR_RD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
   SELECT RD.ReceiptLineNumber
   FROM RECEIPTDETAIL RD (NOLOCK) --WL01
   JOIN EXTERNLOTATTRIBUTE EXT WITH (NOLOCK) ON (EXT.SKU = RD.SKU AND EXT.STORERKEY = RD.STORERKEY
   AND EXT.EXTERNLOT = RD.LOTTABLE07)
   WHERE RD.RECEIPTKEY = @c_Receiptkey 
   AND   RD.ReceiptLineNumber = CASE WHEN ISNULL(RTRIM(@c_ReceiptLineNumber),'') = '' THEN RD.ReceiptLineNumber ELSE @c_ReceiptLineNumber END  

   OPEN CUR_RD  
  
   FETCH NEXT FROM CUR_RD INTO @c_ReceiptLineNumber  
                           
   WHILE @@FETCH_STATUS <> -1   
   BEGIN
	   UPDATE RD WITH (ROWLOCK)
	   SET RD.LOTTABLE04 = EXT.EXTERNLOTTABLE04
	   FROM RECEIPTDETAIL RD --(NOLOCK) --WL01 --WL02
	   JOIN EXTERNLOTATTRIBUTE EXT WITH (NOLOCK) ON (EXT.SKU = RD.SKU AND EXT.STORERKEY = RD.STORERKEY --WL01
	   AND EXT.EXTERNLOT = RD.LOTTABLE07)
	   WHERE RD.RECEIPTKEY = @c_Receiptkey 
	   AND RD.ReceiptLineNumber = @c_ReceiptLineNumber  
        

   SET @n_err = @@ERROR    
     
   IF @n_err <> 0     
   BEGIN    
      SET @n_continue = 3    
      SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
      SET @n_err = 82000      
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update RECEIPTDETAIL Table Failed. (ispPRREC11)'   
                   + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '    
      GOTO QUIT_SP  
   END   
   FETCH NEXT FROM CUR_RD INTO @c_ReceiptLineNumber
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
  
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPRREC11'  
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