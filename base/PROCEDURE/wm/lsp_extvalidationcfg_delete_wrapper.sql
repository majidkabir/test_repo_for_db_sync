SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: lsp_ExtValidationCfg_Delete_Wrapper                 */  
/* Creation Date: 03-AUG-2018                                            */  
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: LFWM-575 - System  ConfigureExtended Validation              */
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/*                                                                       */  
/* Version: 1.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */ 
/* 2021-02-05   mingle01 1.1  Add Big Outer Begin try/Catch             */
/*                            Execute Login if @c_UserName<>SUSER_SNAME()*/
/*************************************************************************/   
CREATE PROCEDURE [WM].[lsp_ExtValidationCfg_Delete_Wrapper]  
   @c_ConfigKey            NVARCHAR(30)
,  @c_Storerkey            NVARCHAR(15)
,  @c_Facility             NVARCHAR(15)
,  @c_RoleName             NVARCHAR(10)
,  @c_DeleteRole           CHAR(1)      = 'N'
,  @b_Success              INT          = 1   OUTPUT   
,  @n_Err                  INT          = 0   OUTPUT
,  @c_Errmsg               NVARCHAR(255)= ''  OUTPUT
,  @c_UserName             NVARCHAR(128)= ''
,  @n_WarningNo            INT = 0            OUTPUT
,  @c_ProceedWithWarning   CHAR(1) = 'N'
AS  
BEGIN  
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_Continue        INT = 1
         , @n_StartTCnt       INT = @@TRANCOUNT

         , @n_InputValidation BIT = 0

   SET @b_Success = 1
   SET @c_ErrMsg = ''

   SET @n_Err = 0 

   --(mingle01) - START   
   IF SUSER_SNAME() <> @c_UserName
   BEGIN
      EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserName OUTPUT, @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT
 
      IF @n_Err <> 0 
      BEGIN
         GOTO EXIT_SP
      END

      EXECUTE AS LOGIN = @c_UserName
   END
   --(mingle01) - END

   --(mingle01) - START
   BEGIN TRY   
      IF @c_ProceedWithWarning = 'N' AND @n_WarningNo < 1
      BEGIN
         SET @n_WarningNo= 1 
         SET @n_continue = 3
         SET @c_Errmsg = 'Delete Validation Config. Do You Want To All its Role Details?'
         GOTO EXIT_SP 
      END

      IF @c_ProceedWithWarning = 'Y' AND @c_DeleteRole = 'Y' AND @n_WarningNo < 2
      BEGIN
         IF EXISTS ( SELECT 1
                     FROM CODELIST WITH (NOLOCK)
                     WHERE ListName = @c_RoleName
                  )
         BEGIN
            SET @n_WarningNo= 2
            SET @n_continue = 3
            SET @c_Errmsg = 'Click Yes to confirm delete role Details.'
            GOTO EXIT_SP 
         END 
         ELSE
         BEGIN
            SET @c_DeleteRole = 'N' 
         END
      END

      IF EXISTS ( SELECT 1
                  FROM CODELKUP CLC WITH (NOLOCK)
                  WHERE CLC.ListName = 'VALDNCFG'
                  AND   CLC.Code = @c_ConfigKey
                  AND   CLC.UDF01 = @c_RoleName
                  AND   CLC.Storerkey= @c_Storerkey
                  AND   CLC.Code2 = @c_Facility
                  )
      BEGIN
         SET @n_InputValidation = 1
      END

      IF @n_InputValidation = 1
      BEGIN 
         BEGIN TRY
            DELETE CODELKUP  
            WHERE ListName = 'VALDNCFG'
            AND Code = @c_ConfigKey
            AND Storerkey = @c_Storerkey
            AND Code2 = @c_Facility
            AND UDF01 = @c_RoleName

         END TRY
 
         BEGIN CATCH
            SET @n_err = 551001
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Delete CODELKUP - VADLNCFG Configkey Fail. (lsp_ExtValidationCfg_Delete_Wrapper)'
                           + '( ' + @c_errmsg + ' )'
         END CATCH 

         IF @b_success = 0 OR @n_Err <> 0        
         BEGIN        
            SET @n_continue = 3      
            GOTO EXIT_SP
         END  
      END
      ELSE
      BEGIN
         IF EXISTS ( SELECT 1
                     FROM STORERCONFIG SC WITH (NOLOCK)
                     WHERE SC.Storerkey = @c_Storerkey
                     AND SC.Configkey = @c_ConfigKey
                     )
         BEGIN
            BEGIN TRY
               DELETE STORERCONFIG 
                  WHERE Storerkey = @c_Storerkey
               AND Configkey = @c_ConfigKey
            END TRY
 
            BEGIN CATCH
               SET @n_err = 551002
               SET @c_ErrMsg = ERROR_MESSAGE()
               SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Delete STORERCONFIG Fail. (lsp_ExtValidationCfg_Delete_Wrapper)'
                              + '( ' + @c_errmsg + ' )'
            END CATCH 

            IF @b_success = 0 OR @n_Err <> 0        
            BEGIN        
               SET @n_continue = 3      
               GOTO EXIT_SP
            END  
         END            
      END

      IF @c_DeleteRole = 'Y'  
      BEGIN
         IF @n_continue IN (1,2)
         BEGIN
            BEGIN TRY
               DELETE CODELKUP 
                WHERE ListName = @c_RoleName 
            END TRY
 
            BEGIN CATCH
               SET @n_err = 551003
               SET @c_ErrMsg = ERROR_MESSAGE()
               SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Delete Codelkup - Role Fail. (lsp_ExtValidationCfg_Delete_Wrapper)'
                              + '( ' + @c_errmsg + ' )'
            END CATCH    

            IF @b_success = 0 OR @n_Err <> 0        
            BEGIN        
               SET @n_continue = 3      
               GOTO EXIT_SP
            END  
         END
   
         IF @n_continue IN (1,2)
         BEGIN
            BEGIN TRY
               DELETE CODELIST 
                WHERE ListName = @c_RoleName 
            END TRY
 
            BEGIN CATCH
               SET @n_err = 551004
               SET @c_ErrMsg = ERROR_MESSAGE()
               SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Delete Codelist - Role Fail. (lsp_ExtValidationCfg_Delete_Wrapper)'
                              + '( ' + @c_errmsg + ' )'
            END CATCH    

            IF @b_success = 0 OR @n_Err <> 0        
            BEGIN        
               SET @n_continue = 3      
               GOTO EXIT_SP
            END  
         END
      END   
   END TRY

   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
   --(mingle01) - END
EXIT_SP: 
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_ExtValidationCfg_Delete_Wrapper'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      SET @n_WarningNo = 0
   END
   REVERT 
END  

GO