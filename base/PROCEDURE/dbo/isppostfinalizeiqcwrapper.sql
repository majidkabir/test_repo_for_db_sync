SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: ispPostFinalizeIQCWrapper                          */  
/* Creation Date: 09-Nov-2018                                           */  
/* Copyright: LFL                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-6868 - Post finalize IQC calling custom sp              */ 
/*                                                                      */  
/* Called By: isp_FinalizeIQC                                           */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Rev   Purposes                                  */ 
/************************************************************************/  
CREATE PROC [dbo].[ispPostFinalizeIQCWrapper]    
     @c_qc_key             NVARCHAR(10)
   , @c_PostFinalizeIQCSP  NVARCHAR(10)   
   , @b_Success            INT           OUTPUT    
   , @n_Err                INT           OUTPUT    
   , @c_ErrMsg             NVARCHAR(250) OUTPUT    
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

   IF @n_Continue=1 OR @n_Continue=2    
   BEGIN    
      IF ISNULL(RTRIM(@c_PostFinalizeIQCSP),'') = ''  
      BEGIN    
         SET @n_Continue = 3    
         SET @n_Err = 63500    
         SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Stored Procedure Name is Blank (ispPostFinalizeIQCWrapper)'
         GOTO EXIT_SP    
      END    
   END -- @n_Continue =1 or @n_Continue = 2    
   
   IF NOT EXISTS (SELECT 1 FROM sys.objects o WHERE NAME = @c_PostFinalizeIQCSP AND TYPE = 'P')
   BEGIN
      SET @n_Continue = 3    
      SET @n_Err = 63505    
      SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Stored Procedure Name ' + @c_PostFinalizeIQCSP + ' Not Found (ispPostFinalizeIQCWrapper)'
      GOTO EXIT_SP          
   END

   SET @c_SQL = N'  
      EXECUTE ' + @c_PostFinalizeIQCSP          + CHAR(13) +  
      '  @c_qc_key = @c_qc_key '                + CHAR(13) +  
      ', @b_Success  = @b_Success     OUTPUT '  + CHAR(13) + 
      ', @n_Err      = @n_Err         OUTPUT '  + CHAR(13) +  
      ', @c_ErrMsg   = @c_ErrMsg      OUTPUT '  

   SET @c_SQLParm =  N'@c_qc_key  NVARCHAR(10)'  
                  +   ', @b_Success INT OUTPUT'
                  +   ', @n_Err     INT OUTPUT'
                  +   ', @c_ErrMsg  NVARCHAR(250) OUTPUT ' 
        
   EXEC sp_ExecuteSQL @c_SQL
                     ,@c_SQLParm
                     ,@c_qc_key 
                     ,@b_Success OUTPUT
                     ,@n_Err     OUTPUT
                     ,@c_ErrMsg  OUTPUT 
  
   IF @@ERROR <> 0 OR @b_Success <> 1  
   BEGIN  
      SET @n_Continue= 3    
      SET @n_Err     = 63510    
      SET @c_ErrMsg  =  'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to EXEC ' + @c_PostFinalizeIQCSP +   
                        CASE WHEN ISNULL(@c_ErrMsg, '') <> '' THEN ' - ' + @c_ErrMsg ELSE '' END + ' (ispPostFinalizeIQCWrapper)'
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
  
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPostFinalizeIQCWrapper'    
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012   
      RETURN    
   END    
   ELSE    
   BEGIN    
      SET @b_Success = 1    
      RETURN    
   END    
    
END -- Procedure  

GO