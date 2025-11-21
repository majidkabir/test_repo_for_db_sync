SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: ispPostAllocationWrapper                           */  
/* Creation Date: 13-Nov-2013                                           */  
/* Copyright: IDS                                                       */  
/* Written by: Shong                                                    */  
/*                                                                      */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Called By: nsp_OrderProcessing_Wrapper                               */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 1.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Rev   Purposes                                  */  
/* 13-11-2013   Shong   1.0   Initial Version                           */  
/* 29-09-2014   NJOW01  1.1   306662-Change PostAllocationSP support    */
/*                            allocation strategykey pickcode setup     */
/* 17-04-2018   NJOW02  1.1   WMS-4345 Support post wave                */ 
/************************************************************************/  
CREATE PROC [dbo].[ispPostAllocationWrapper]    
     @c_OrderKey         NVARCHAR(10) = ''  
   , @c_LoadKey          NVARCHAR(10) = ''
   , @c_Wavekey          NVARCHAR(10) = ''  --NJOW02
   , @c_PostAllocationSP NVARCHAR(30)    
   , @b_Success     INT           OUTPUT    
   , @n_Err         INT           OUTPUT    
   , @c_ErrMsg      NVARCHAR(250) OUTPUT    
   , @b_debug       INT = 0    
AS    
BEGIN    
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF     
    
   DECLARE  @n_Continue                   INT,    
            @n_StartTCnt                  INT, -- Holds the current transaction count     
            @c_sCurrentLineNumber         NVARCHAR(5),  
            @c_UOM                        NVARCHAR(10),    
            @c_LocationTypeOverride       NVARCHAR(10),  
            @c_LocationTypeOverRideStripe NVARCHAR(10)  
  
   DECLARE  @c_SQL         NVARCHAR(MAX),      
            @c_SQLParm     NVARCHAR(MAX)      
    
   SELECT @n_StartTCnt=@@TRANCOUNT , @n_Continue=1, @b_Success=1, @n_Err=0  
   SELECT @c_ErrMsg=''  
   SELECT @c_sCurrentLineNumber = SPACE(5)    
    
   IF @n_Continue=1 OR @n_Continue=2    
   BEGIN    
      IF ISNULL(RTRIM(@c_PostAllocationSP),'') = ''  
      BEGIN    
         SELECT @n_Continue = 3    
         SELECT @n_Err = 63500    
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Stored Procedure Name/Allocate Strategykey is Blank (ispPostAllocationWrapper)'
         GOTO EXIT_SP    
      END    
   END -- @n_Continue =1 or @n_Continue = 2    
   
   IF NOT EXISTS (SELECT 1 FROM sys.objects o WHERE NAME = @c_PostAllocationSP AND TYPE = 'P')
      AND NOT EXISTS(SELECT 1 FROM AllocateStrategy (NOLOCK) WHERE AllocateStrategyKey = @c_PostAllocationSP) --NJOW01
   BEGIN
      SELECT @n_Continue = 3    
      SELECT @n_Err = 63501    
      SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Stored Procedure Name/Allocate Strategykey ' + @c_PostAllocationSP + ' Not Found (ispPostAllocationWrapper)'
      GOTO EXIT_SP          
   END
      
   IF EXISTS (SELECT 1 FROM sys.objects o WHERE NAME = @c_PostAllocationSP AND TYPE = 'P')
   BEGIN 
      IF EXISTS (SELECT 1
                 FROM [INFORMATION_SCHEMA].[PARAMETERS] 
                 WHERE SPECIFIC_NAME = @c_PostAllocationSP
                 AND PARAMETER_NAME = '@c_wavekey')  --NJOW02
      BEGIN             
         SET @c_SQL = N'  
            EXECUTE ' + @c_PostAllocationSP + CHAR(13) +  
            '  @c_OrderKey = @c_OrderKey ' + CHAR(13) +  
            ', @c_LoadKey  = @c_LoadKey  ' + CHAR(13) +
            ', @c_WaveKey  = @c_WaveKey  ' + CHAR(13) +
            ', @b_Success  = @b_Success     OUTPUT ' + CHAR(13) + 
            ', @n_Err      = @n_Err       OUTPUT ' + CHAR(13) +  
            ', @c_ErrMsg   = @c_ErrMsg      OUTPUT ' + CHAR(13) + 
            ', @b_debug    = @b_Debug ' + CHAR(13) 

         SET @c_SQLParm =  N'@c_OrderKey NVARCHAR(10), @c_LoadKey NVARCHAR(10), @c_Wavekey NVARCHAR(10), ' +   
                            '@b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT, @b_Debug INT'         
         EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_OrderKey, @c_LoadKey, @c_Wavekey,
                            @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT, @b_debug  
      END
      ELSE IF ISNULL(@c_Wavekey,'') = '' --NJOW04 Backward compatibility. if the custom sp is old version without wavekey and call from wave. don't execute the sp.
      BEGIN
         SET @c_SQL = N'  
            EXECUTE ' + @c_PostAllocationSP + CHAR(13) +  
            '  @c_OrderKey = @c_OrderKey ' + CHAR(13) +  
            ', @c_LoadKey  = @c_LoadKey  ' + CHAR(13) +
            ', @b_Success  = @b_Success     OUTPUT ' + CHAR(13) + 
            ', @n_Err      = @n_Err       OUTPUT ' + CHAR(13) +  
            ', @c_ErrMsg   = @c_ErrMsg      OUTPUT ' + CHAR(13) + 
            ', @b_debug    = @b_Debug ' + CHAR(13) 

         SET @c_SQLParm =  N'@c_OrderKey NVARCHAR(10), @c_LoadKey NVARCHAR(10), ' +   
                            '@b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT, @b_Debug INT'         
         EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_OrderKey, @c_LoadKey,  
                            @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT, @b_debug  
      END      
      
      
      IF @@ERROR <> 0 OR @b_Success <> 1  
      BEGIN  
         SELECT @n_Continue = 3    
         SELECT @n_Err = 63502    
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to EXEC ' + @c_PostAllocationSP +   
                          CASE WHEN ISNULL(@c_ErrMsg, '') <> '' THEN ' - ' + @c_ErrMsg ELSE '' END + ' (ispPostAllocationWrapper)'
         GOTO EXIT_SP                          
      END  
   END
   ELSE
   BEGIN
      --NJOW01
      EXECUTE dbo.ispPostOrderProcessingStrategy
              @c_Orderkey
            , @c_LoadKey   
            , @c_Wavekey --NJOW02
            , @c_PostAllocationSP  --Allocation Strategykey  
            , @b_Success OUTPUT  
            , @n_Err     OUTPUT  
            , @c_ErrMsg  OUTPUT  
            , @b_debug 
      
      IF @@ERROR <> 0 OR @b_Success <> 1  
      BEGIN  
         SELECT @n_Continue = 3  
      END
   END

EXIT_SP:
    
   IF @n_Continue=3  -- Error Occured - Process And Return    
   BEGIN    
      SELECT @b_Success = 0    
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPostAllocationWrapper'    
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
      RETURN    
   END    
   ELSE    
   BEGIN    
      SELECT @b_Success = 1    
      WHILE @@TRANCOUNT > @n_StartTCnt    
      BEGIN    
         COMMIT TRAN    
      END    
      RETURN    
   END    
    
END -- Procedure  

GO