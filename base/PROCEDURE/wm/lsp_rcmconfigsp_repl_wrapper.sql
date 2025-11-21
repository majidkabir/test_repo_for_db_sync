SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: lsp_RCMConfigSP_REPL_Wrapper                        */  
/* Creation Date: 2022-08-01                                             */  
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: LFWM-3641 -  [CN] DYSON Voice Picking replenishment trigger  */
/*          button New                                                   */
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/*                                                                       */  
/* Version: 1.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */
/* 2022-08-01  Wan      1.0   Created & DevOps Combine Script            */
/*************************************************************************/   
CREATE PROCEDURE [WM].[lsp_RCMConfigSP_REPL_Wrapper]  
   @c_Storerkey            NVARCHAR(15)
,  @c_facility             NVARCHAR(5) 
,  @b_Success              INT          = 1   OUTPUT   
,  @n_Err                  INT          = 0   OUTPUT
,  @c_Errmsg               NVARCHAR(255)= ''  OUTPUT
,  @c_UserName             NVARCHAR(128)= ''
,  @c_Code                 NVARCHAR(30) = ''           
AS  
BEGIN  
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue           INT = 1
         , @n_StartTCnt          INT = @@TRANCOUNT

         , @n_Count              INT = 0 
         , @c_RCMConfigSP        NVARCHAR(60) = ''
         
         , @c_ReplGroup          NVARCHAR(10) = ''
         , @c_Zone02             NVARCHAR(10) = ''
         , @c_Zone03             NVARCHAR(10) = ''
         , @c_Zone04             NVARCHAR(10) = ''
         , @c_Zone05             NVARCHAR(10) = '' 
         , @c_Zone06             NVARCHAR(10) = ''
         , @c_Zone07             NVARCHAR(10) = ''
         , @c_Zone08             NVARCHAR(10) = ''
         , @c_Zone09             NVARCHAR(10) = ''
         , @c_Zone10             NVARCHAR(500)= ''
         , @c_Zone11             NVARCHAR(500)= ''                                       
         , @c_Zone12             NVARCHAR(10) = '' 

   SET @b_Success = 1
   SET @c_ErrMsg = ''

   SET @n_Err = 0 
   IF SUSER_SNAME() <> @c_UserName
   BEGIN
      EXEC [WM].[lsp_SetUser] 
            @c_UserName = @c_UserName  OUTPUT
         ,  @n_Err      = @n_Err       OUTPUT
         ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT
                
      IF @n_Err <> 0 
      BEGIN
         GOTO EXIT_SP
      END
    
      EXECUTE AS LOGIN = @c_UserName
   END

   BEGIN TRY
      WHILE  @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END

      BEGIN TRAN

      SELECT @c_RCMConfigSP = RTRIM(CL.Long)
      FROM CODELKUP CL (NOLOCK)
      WHERE CL.ListName = 'RCMConfig'
      AND   CL.Code = @c_Code
      AND   CL.UDF01= 'replenishment'
      AND   CL.Short= 'storedproc'
      AND   CL.Storerkey = @c_Storerkey


      IF @c_RCMConfigSP <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM sys.objects (NOLOCK) WHERE Object_ID(@c_RCMConfigSP) = object_id AND [Type] = 'P')
         BEGIN
            GOTO EXIT_SP
         END
      END

      BEGIN TRY   
         SELECT TOP 1
                  @c_ReplGroup   = r.ReplenishmentGroup
               ,  @c_Zone02      = r.Zone02 
               ,  @c_Zone03      = r.Zone03 
               ,  @c_Zone04      = r.Zone04 
               ,  @c_Zone05      = r.Zone05  
               ,  @c_Zone06      = r.Zone06 
               ,  @c_Zone07      = r.Zone07 
               ,  @c_Zone08      = r.Zone08 
               ,  @c_Zone09      = r.Zone09 
               ,  @c_Zone10      = r.Zone10
               ,  @c_Zone11      = r.Zone11                                       
               ,  @c_Zone12      = r.Zone12 
         FROM dbo.REPLENISHMENTPARMS AS r WITH (NOLOCK)
         WHERE r.Storerkey = @c_Storerkey
         AND r.Facility = @c_Facility
      
         SET @b_Success = 1

         EXEC @c_RCMConfigSP 
            @c_Storerkey   = @c_Storerkey
         ,  @c_Facility    = @c_facility
         ,  @c_ReplGroup   = @c_ReplGroup
         ,  @c_Zone02      = @c_Zone02 
         ,  @c_Zone03      = @c_Zone03 
         ,  @c_Zone04      = @c_Zone04 
         ,  @c_Zone05      = @c_Zone05  
         ,  @c_Zone06      = @c_Zone06 
         ,  @c_Zone07      = @c_Zone07 
         ,  @c_Zone08      = @c_Zone08 
         ,  @c_Zone09      = @c_Zone09 
         ,  @c_Zone10      = @c_Zone10
         ,  @c_Zone11      = @c_Zone11                                       
         ,  @c_Zone12      = @c_Zone12                   
         ,  @b_Success     = @b_Success   OUTPUT
         ,  @n_Err         = @n_Err       OUTPUT  
         ,  @c_ErrMsg      = @c_ErrMsg    OUTPUT   
         ,  @c_Code        = @c_Code        

      END TRY

      BEGIN CATCH
         SET @n_Continue = 3
         SET @n_err = 558151
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error Executing Replenishment''s RCMConfig Custom SP: ' + @c_RCMConfigSP + '. (lsp_RCMConfigSP_REPL_Wrapper)'
                        + '( ' + @c_errmsg + ' ) |' + @c_RCMConfigSP
      END CATCH    
      
      IF @n_err <> 0 
      BEGIN
         SET @n_Continue = 3
         GOTO EXIT_SP
      END
   END TRY
   
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH

   EXIT_SP:
   
   IF (XACT_STATE()) = -1  
   BEGIN
      SET @n_Continue = 3 
      ROLLBACK TRAN
   END  
      
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @n_StartTCnt = 0 AND @@TRANCOUNT > @n_StartTCnt
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_RCMConfigSP_REPL_Wrapper'
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
   BEGIN
      BEGIN TRAN
   END

   REVERT      
END  

GO