SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_VASCancJob_Wrapper                             */  
/* Creation Date: 23-JUN-2015                                           */  
/* Copyright: IDS                                                       */  
/* Written by: YTWan                                                    */  
/*                                                                      */  
/* Purpose: SOS#318089 - Project Merlion VAP Add or Delete Work Order   */ 
/*                                                                      */  
/* Called By: ue_cancjob                                                */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Rev   Purposes                                  */ 
/************************************************************************/  
CREATE PROC [dbo].[isp_VASCancJob_Wrapper]    
     @c_JobKey     NVARCHAR(10)
   , @b_Success    INT           OUTPUT    
   , @n_Err        INT           OUTPUT    
   , @c_ErrMsg     NVARCHAR(250) OUTPUT    
AS    
BEGIN    
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF  
    
   DECLARE  @n_Continue       INT     
         ,  @n_StartTCnt      INT  -- Holds the current transaction count     
  
         ,  @c_Facility       NVARCHAR(5)
         ,  @c_Storerkey      NVARCHAR(15)
         ,  @c_VASCancJobSP   NVARCHAR(30)

         ,  @c_SQL            NVARCHAR(MAX)
         ,  @c_SQLParm        NVARCHAR(MAX)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue   =  1
   SET @b_Success    =  1 
   SET @n_Err        =  0  
   SET @c_ErrMsg     =  '' 

   SELECT TOP 1 @c_Storerkey = Storerkey
   FROM WORKORDERJOB WITH (NOLOCK)
   WHERE JobKey = @c_JobKey 

   SELECT @c_VASCancJobSP = ISNULL(SValue,'')
   FROM STORERCONFIG WITH (NOLOCK)
   WHERE Storerkey = @c_Storerkey
   AND   Configkey = 'VASCancJob_SP'

   BEGIN TRAN

   IF ISNULL(RTRIM(@c_VASCancJobSP),'') <> ''  
   BEGIN    
      IF NOT EXISTS (SELECT 1 FROM sys.objects o WHERE NAME = @c_VASCancJobSP AND TYPE = 'P')
      BEGIN
         SET @n_Continue = 3    
         SET @n_Err = 63501    
         SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Stored Procedure Name ' + @c_VASCancJobSP + ' Not Found (isp_VASCancJob_Wrapper)'
         GOTO QUIT_SP          
      END
   	
      SET @c_SQL = N'EXECUTE ' + @c_VASCancJobSP  
                +  '  @c_JobKey   = @c_JobKey '   
                +  ', @b_Success  = @b_Success     OUTPUT '  
                +  ', @n_Err      = @n_Err         OUTPUT '  
                +  ', @c_ErrMsg   = @c_ErrMsg      OUTPUT '  


      SET @c_SQLParm =  N'@c_JobKey  NVARCHAR(10), '  
                     +   '@b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT'
            
      EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_JobKey, 
                         @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT 

      IF @@ERROR <> 0 OR @b_Success <> 1  
      BEGIN  
         SET @n_Continue= 3    
         SET @n_Err     = 63502    
         SET @c_ErrMsg  =  'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to EXEC ' + @c_VASCancJobSP +   
                           CASE WHEN ISNULL(@c_ErrMsg, '') <> '' THEN ' - ' + @c_ErrMsg ELSE '' END + ' (isp_VASCancJob_Wrapper)'
         GOTO QUIT_SP                          
      END 
   END

   IF EXISTS ( SELECT 1
               FROM WORKORDERJOBDETAIL WITH (NOLOCK)
               WHERE  JobKey = @c_JobKey
               AND    JobStatus > '0'
             )
   BEGIN
      SET @n_continue= 3
      SET @n_err     = 63505  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+'. Job is in progress. Job Cancel Reject.' 
      GOTO QUIT_SP   
   END

   UPDATE WORKORDERJOBDETAIL WITH (ROWLOCK)
   SET    JobStatus = '8'
   WHERE  JobKey = @c_JobKey

   SET @n_err = @@ERROR

   IF @n_err <> 0
   BEGIN
      SET @n_continue= 3
      SET @n_err     = 63510  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERJOBDETAIL. (isp_VASCancJob_Wrapper)' 
      GOTO QUIT_SP
   END
QUIT_SP:
   IF @n_Continue=3  -- Error Occured - Process And Return    
   BEGIN    
      SET @b_Success = 0    
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt    
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

      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_VASCancJob_Wrapper'    
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