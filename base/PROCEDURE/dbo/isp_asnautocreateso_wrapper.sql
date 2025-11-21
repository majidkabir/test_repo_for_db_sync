SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_ASNAutoCreateSO_Wrapper                        */  
/* Creation Date: 19-APR-2019                                           */  
/* Copyright: IDS                                                       */  
/* Written by: WLCHOOI                                                  */  
/*                                                                      */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Called By: ispFinalizeReceipt                                        */  
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Rev   Purposes                                  */ 
/************************************************************************/  
CREATE PROC [dbo].[isp_ASNAutoCreateSO_Wrapper]    
     @c_ReceiptKey            NVARCHAR(10)
   , @c_ReceiptLineNumber     NVARCHAR(5) = ''     
   , @b_Success               INT           OUTPUT    
   , @n_Err                   INT           OUTPUT    
   , @c_ErrMsg                NVARCHAR(250) OUTPUT    
   , @b_debug                 INT = 0    
AS    
BEGIN    
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF  
    
   DECLARE  @n_Continue                INT     
         ,  @n_StartTCnt               INT  -- Holds the current transaction count     
  
   DECLARE  @c_SQL                     NVARCHAR(MAX)      
         ,  @c_SQLParm                 NVARCHAR(MAX)  
         ,  @c_RecType                 NVARCHAR(10)
         ,  @c_Storerkey               NVARCHAR(15)
         ,  @c_ASNAutoCreateSOSP       NVARCHAR(50)
 
   SET @n_StartTCnt  =  @@TRANCOUNT
   SET @n_Continue   =  1
   SET @b_Success    =  1 
   SET @n_Err        =  0  
   SET @c_ErrMsg     =  ''  

   SET @c_ReceiptLineNumber = ISNULL(RTRIM(@c_ReceiptLineNumber),'')    --(Wan01)

   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      SELECT TOP 1 @c_RecType   = RECTYPE 
                  ,@c_Storerkey = StorerKey
      FROM RECEIPT (NOLOCK) 
      WHERE RECEIPTKEY = @c_ReceiptKey

      SELECT TOP 1 @c_ASNAutoCreateSOSP = ISNULL(RTRIM(Long),'')
      FROM CODELKUP WITH (NOLOCK)
      WHERE ListName = 'ASNTYP2SO' AND Code = @c_RecType
      AND (StorerKey = @c_StorerKey OR Storerkey = '')
      ORDER BY CASE WHEN STORERKEY = '' THEN 2 ELSE 1 END, STORERKEY
   END
   
   IF (@n_continue = 1 OR @n_continue = 2)  
   BEGIN    
      IF ISNULL(RTRIM(@c_ASNAutoCreateSOSP),'') = ''  
      BEGIN    
         --SELECT @n_Continue = 3    
         --SELECT @n_Err = 63500    
         --SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Stored Procedure Name is Blank (isp_ASNAutoCreateSO_Wrapper)'
         GOTO EXIT_SP    
      END    
   END -- @n_Continue =1 or @n_Continue = 2    
   
   IF NOT EXISTS (SELECT 1 FROM sys.objects o WHERE NAME = @c_ASNAutoCreateSOSP AND TYPE = 'P')
   BEGIN
      SELECT @n_Continue = 3    
      SELECT @n_Err = 63501    
      SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Stored Procedure Name ' + @c_ASNAutoCreateSOSP + ' Not Found (isp_ASNAutoCreateSO_Wrapper)'
      GOTO EXIT_SP          
   END

   SET @c_SQL = N'  
      EXECUTE ' + @c_ASNAutoCreateSOSP + CHAR(13) +  
      '  @c_ReceiptKey  = @c_ReceiptKey '  + CHAR(13) +  
      ', @c_ReceiptLineNumber  = @c_ReceiptLineNumber '  + CHAR(13) +                  --(Wan01) 
      ', @b_Success  = @b_Success     OUTPUT ' + CHAR(13) + 
      ', @n_Err      = @n_Err         OUTPUT ' + CHAR(13) +  
      ', @c_ErrMsg   = @c_ErrMsg      OUTPUT '  

   IF ((@n_continue = 1 OR @n_continue = 2) AND @b_debug = 1)
   BEGIN
      PRINT @c_SQL
   END

   SET @c_SQLParm =  N'@c_ReceiptKey  NVARCHAR(10), '  
                  +   '@c_ReceiptLineNumber  NVARCHAR(10), '                           --(Wan01) 
                  +   '@b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT '         
   EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_ReceiptKey, @c_ReceiptLineNumber,         --(Wan01)
                      @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT 
  
   IF @@ERROR <> 0 OR @b_Success <> 1  
   BEGIN  
      SET @n_Continue= 3    
      SET @n_Err     = 63502    
      SET @c_ErrMsg  =  'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to EXEC ' + @c_ASNAutoCreateSOSP +   
                        CASE WHEN ISNULL(@c_ErrMsg, '') <> '' THEN ' - ' + @c_ErrMsg ELSE '' END + ' (isp_ASNAutoCreateSO_Wrapper)'
      GOTO EXIT_SP                          
   END 
EXIT_SP:

   --IF CURSOR_STATUS('LOCAL' , 'CUR_ASN') in (0 , 1)
   --BEGIN
   --   CLOSE CUR_ASN
   --   DEALLOCATE CUR_ASN   
   --END

   IF @n_Continue=3  -- Error Occured - Process And Return    
   BEGIN    
      SET @b_Success = 0    
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt    
      BEGIN    
         ROLLBACK TRAN    
      END    
  
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_ASNAutoCreateSO_Wrapper'    
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
      --RAISERROR @n_Err @c_ErrMsg    
      RETURN    
   END    
   ELSE    
   BEGIN    
      SET @b_Success = 1    
      RETURN    
   END    
    
END -- Procedure  

GO