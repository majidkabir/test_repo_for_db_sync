SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: ispPostFinalizeReceiptWrapper                      */  
/* Creation Date: 23-DEC-2013                                           */  
/* Copyright: IDS                                                       */  
/* Written by: YTWan                                                    */  
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
/* 2014-01-20   YTWan   1.1   SOS#298639 - Washington - Finalize by     */
/*                            Receipt Line. Add Default parameters      */
/*                            @c_ReceiptLineNumber.(Wan01)              */ 
/* 14-Apr-2014  TLTING  1.2   SQL2012 Fixing Bugs                       */
/************************************************************************/  
CREATE PROC [dbo].[ispPostFinalizeReceiptWrapper]    
     @c_ReceiptKey            NVARCHAR(10)
   , @c_ReceiptLineNumber     NVARCHAR(5) = ''       --(Wan01)
   , @c_PostFinalizeReceiptSP NVARCHAR(30)   
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
   
    
   SET @n_StartTCnt  =  @@TRANCOUNT
   SET @n_Continue   =  1
   SET @b_Success    =  1 
   SET @n_Err        =  0  
   SET @c_ErrMsg     =  ''  

   SET @c_ReceiptLineNumber = ISNULL(RTRIM(@c_ReceiptLineNumber),'')    --(Wan01)

   IF @n_Continue=1 OR @n_Continue=2    
   BEGIN    
      IF ISNULL(RTRIM(@c_PostFinalizeReceiptSP),'') = ''  
      BEGIN    
         SELECT @n_Continue = 3    
         SELECT @n_Err = 63500    
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Stored Procedure Name is Blank (ispPostFinalizeReceiptWrapper)'
         GOTO EXIT_SP    
      END    
   END -- @n_Continue =1 or @n_Continue = 2    
   
   IF NOT EXISTS (SELECT 1 FROM sys.objects o WHERE NAME = @c_PostFinalizeReceiptSP AND TYPE = 'P')
   BEGIN
      SELECT @n_Continue = 3    
      SELECT @n_Err = 63501    
      SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Stored Procedure Name ' + @c_PostFinalizeReceiptSP + ' Not Found (ispPostFinalizeReceiptWrapper)'
      GOTO EXIT_SP          
   END

   SET @c_SQL = N'  
      EXECUTE ' + @c_PostFinalizeReceiptSP + CHAR(13) +  
      '  @c_ReceiptKey  = @c_ReceiptKey '  + CHAR(13) +  
      ', @c_ReceiptLineNumber  = @c_ReceiptLineNumber '  + CHAR(13) +                  --(Wan01) 
      ', @b_Success  = @b_Success     OUTPUT ' + CHAR(13) + 
      ', @n_Err      = @n_Err         OUTPUT ' + CHAR(13) +  
      ', @c_ErrMsg   = @c_ErrMsg      OUTPUT '  


   SET @c_SQLParm =  N'@c_ReceiptKey  NVARCHAR(10), '  
                  +   '@c_ReceiptLineNumber  NVARCHAR(10), '                           --(Wan01) 
                  +   '@b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT '         
   EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_ReceiptKey, @c_ReceiptLineNumber,         --(Wan01)
                      @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT 
  
   IF @@ERROR <> 0 OR @b_Success <> 1  
   BEGIN  
      SET @n_Continue= 3    
      SET @n_Err     = 63502    
      SET @c_ErrMsg  =  'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to EXEC ' + @c_PostFinalizeReceiptSP +   
                        CASE WHEN ISNULL(@c_ErrMsg, '') <> '' THEN ' - ' + @c_ErrMsg ELSE '' END + ' (ispPostFinalizeReceiptWrapper)'
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
  
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPostFinalizeReceiptWrapper'    
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