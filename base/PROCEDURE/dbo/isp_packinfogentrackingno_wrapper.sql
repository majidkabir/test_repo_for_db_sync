SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure: isp_PackinfoGenTrackingNo_Wrapper                  */    
/* Creation Date: 30-Jul-2021                                           */    
/* Copyright: LFL                                                       */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose: WMS-17609 - call custom stored proc to generate packinfo    */   
/*          trackingno                                                  */   
/*          Sub SP Naming: ispPKINFOGENTRK??                            */  
/*                                                                      */   
/* Called By: ntrPackDetailAdd                                          */    
/*                                                                      */    
/* PVCS Version: 7.0                                                    */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author  Rev   Purposes                                  */   
/************************************************************************/    
CREATE PROC [dbo].[isp_PackinfoGenTrackingNo_Wrapper]      
       @c_Pickslipno                NVARCHAR(10)  
     , @n_CartonNo                  INT  
     , @c_PackinfoGenTrackingNo_SP  NVARCHAR(30)  
     , @b_Success                   INT           OUTPUT    
     , @n_Err                       INT           OUTPUT     
     , @c_ErrMsg                    NVARCHAR(250) OUTPUT    
AS      
BEGIN      
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF    
      
   DECLARE  @n_Continue                INT       
         ,  @n_StartTCnt               INT  -- Holds the current transaction count       
         ,  @c_SQL                     NVARCHAR(MAX)        
         ,  @c_SQLParm                 NVARCHAR(MAX)    
         
   SET @n_StartTCnt  =  @@TRANCOUNT  
   SET @n_Continue   =  1  
   SET @b_Success    =  1   
   SET @n_Err        =  0    
   SET @c_ErrMsg     =  ''    
  
   IF ISNULL(RTRIM(@c_PackinfoGenTrackingNo_SP),'') = ''    
   BEGIN      
      SET @n_Continue = 3      
      SET @n_Err = 63500      
      SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Stored Procedure Name is Blank (isp_PackinfoGenTrackingNo_Wrapper)'  
      GOTO EXIT_SP      
   END      
     
   IF NOT EXISTS (SELECT 1 FROM sys.objects o WHERE NAME = @c_PackinfoGenTrackingNo_SP AND TYPE = 'P')  
   BEGIN  
      SET @n_Continue = 3      
      SET @n_Err = 63510      
      SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Stored Procedure Name ' + @c_PackinfoGenTrackingNo_SP + ' Not Found (isp_PackinfoGenTrackingNo_Wrapper)'  
      GOTO EXIT_SP            
   END  
  
   SET @c_SQL = N'    
      EXECUTE ' + @c_PackinfoGenTrackingNo_SP + CHAR(13) +    
      '  @c_PickSlipNo = @c_PickslipNo '  + CHAR(13) +    
      ', @n_CartonNo = @n_CartonNo '  + CHAR(13) +    
      ', @b_Success  = @b_Success     OUTPUT ' + CHAR(13) +   
      ', @n_Err      = @n_Err         OUTPUT ' + CHAR(13) +    
      ', @c_ErrMsg   = @c_ErrMsg      OUTPUT '    
  
  
   SET @c_SQLParm =  N'@c_PickslipNo NVARCHAR(10), @n_CartonNo INT,'    
                  +   '@b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT '           
   EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_PickslipNo, @n_CartonNo,  
                      @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT   
    
  
   IF @@ERROR <> 0 OR @b_Success <> 1    
   BEGIN    
      SET @n_Continue= 3      
      SET @n_Err     = 63520      
      SET @c_ErrMsg  =  'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to EXEC ' + @c_PackinfoGenTrackingNo_SP +     
                        CASE WHEN ISNULL(@c_ErrMsg, '') <> '' THEN ' - ' + @c_ErrMsg ELSE '' END + ' (isp_PackinfoGenTrackingNo_Wrapper)'  
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
    
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_PackinfoGenTrackingNo_Wrapper'      
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