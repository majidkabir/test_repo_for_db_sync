SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: ispPostFinalizeKitWrapper                          */  
/* Creation Date: 21-APR-2014                                           */  
/* Copyright: IDS                                                       */  
/* Written by: YTWan                                                    */  
/*                                                                      */  
/* Purpose: SOS#304838 - ANF - Allocation strategy for Transfer         */ 
/*                                                                      */  
/* Called By: ntrKitHeaderUpdate                                        */  
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Rev   Purposes                                  */ 
/************************************************************************/  
CREATE PROC [dbo].[ispPostFinalizeKitWrapper]    
     @c_KitKey              NVARCHAR(10)
   , @c_PostFinalizeKitSP        NVARCHAR(30)   
   , @b_Success                  INT           OUTPUT    
   , @n_Err                      INT           OUTPUT    
   , @c_ErrMsg                   NVARCHAR(250) OUTPUT    
   , @b_debug                    INT = 0    
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

   IF ISNULL(RTRIM(@c_PostFinalizeKitSP),'') = ''  
   BEGIN    
      SET @n_Continue = 3    
      SET @n_Err = 63500    
      SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Stored Procedure Name is Blank (ispPostFinalizeKitWrapper)'
      GOTO EXIT_SP    
   END    
   
   IF NOT EXISTS (SELECT 1 FROM sys.objects o WHERE NAME = @c_PostFinalizeKitSP AND TYPE = 'P')
   BEGIN
      SET @n_Continue = 3    
      SET @n_Err = 63501    
      SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Stored Procedure Name ' + @c_PostFinalizeKitSP + ' Not Found (ispPostFinalizeKitWrapper)'
      GOTO EXIT_SP          
   END

   SET @c_SQL = N'  
      EXECUTE ' + @c_PostFinalizeKitSP + CHAR(13) +  
      '  @c_KitKey   = @c_KitKey '  + CHAR(13) +  
      ', @b_Success  = @b_Success     OUTPUT ' + CHAR(13) + 
      ', @n_Err      = @n_Err         OUTPUT ' + CHAR(13) +  
      ', @c_ErrMsg   = @c_ErrMsg      OUTPUT '  


   SET @c_SQLParm =  N'@c_KitKey  NVARCHAR(10), '  
                  +   '@b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT '         
   EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_KitKey, 
                      @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT 
  

   IF @@ERROR <> 0 OR @b_Success <> 1  
   BEGIN  
      SET @n_Continue= 3    
      SET @n_Err     = 63502    
      SET @c_ErrMsg  =  'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to EXEC ' + @c_PostFinalizeKitSP +   
                        CASE WHEN ISNULL(@c_ErrMsg, '') <> '' THEN ' - ' + @c_ErrMsg ELSE '' END + ' (ispPostFinalizeKitWrapper)'
      GOTO EXIT_SP                          
   END 
EXIT_SP:
   IF @n_Continue=3  -- Error Occured - Process And Return    
   BEGIN    
      SET @b_Success = 0    
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt    
      BEGIN    
         ROLLBACK TRAN    
      END    
  
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPostFinalizeKitWrapper'    
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
      RETURN    
   END    
   ELSE    
   BEGIN
      SET @b_Success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END    
   
      RETURN    
   END    
    
END -- Procedure  

GO