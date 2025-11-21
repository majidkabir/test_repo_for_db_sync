SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: lsp_KitReleaseTask_Wrapper                          */
/* Creation Date: 2022-09-26                                            */
/* Copyright: LFL                                                       */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: LFWM-3777 - UAT-CN  SCE UAT and Prod add release task action*/
/*        : button in Kit module                                        */
/*                                                                      */
/* Called By: SCE                                                       */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 8.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver.  Purposes                                  */
/* 2021-09-28  Wan      1.0   Created & DevOps Combine Script.          */
/************************************************************************/
CREATE PROC [WM].[lsp_KitReleaseTask_Wrapper]
      @c_KitKey               NVARCHAR(10) = ''       
   ,  @b_Success              INT = 1           OUTPUT
   ,  @n_err                  INT = 0           OUTPUT
   ,  @c_ErrMsg               NVARCHAR(255)     OUTPUT
   ,  @n_WarningNo            INT          = 0  OUTPUT
   ,  @c_ProceedWithWarning   CHAR(1)      = 'N'
   ,  @c_UserName             NVARCHAR(128)= ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @n_StartTCnt            INT = @@TRANCOUNT
         ,  @n_Continue             INT = 1

         ,  @c_Facility             NVARCHAR(5)  = ''
         ,  @c_Storerkey            NVARCHAR(15) = '' 
         
         ,  @c_KitReleaseTask_Opt1  NVARCHAR(30) = ''        

   SET @b_Success = 1
   SET @n_Err     = 0

   BEGIN TRAN        

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
      IF @c_ProceedWithWarning = 'N' AND @n_WarningNo < 1
      BEGIN
         SET @n_WarningNo = 1
         SET @c_ErrMsg = 'Confirm to Release task?'
         
         SELECT @c_Facility = k.KITKey
               ,@c_Storerkey= k.Storerkey
         FROM dbo.KIT AS k WITH (NOLOCK)
         WHERE k.KITKey = @c_KitKey
         
         SELECT @c_KitReleaseTask_Opt1 = ISNULL(fgr.Option1,'')
         FROM dbo.fnc_GetRight2(@c_Facility, @c_Storerkey, '', 'KitReleaseTask_SP') AS fgr
         WHERE fgr.Authority <> ''
         AND EXISTS (SELECT 1 FROM dbo.SysObjects AS so (NOLOCK) WHERE so.NAME = fgr.Authority AND so.TYPE = 'P')
         
         IF  @c_KitReleaseTask_Opt1 <> '' 
         BEGIN
            SET @c_ErrMsg = @c_KitReleaseTask_Opt1
            
            IF CHARINDEX(@c_ErrMsg,'?', 1) > 0
            BEGIN
               SET @c_ErrMsg = @c_ErrMsg + '?'
            END
         END
         
         
         GOTO EXIT_SP
      END

      EXEC [dbo].[isp_kitReleaseTask_Wrapper]
           @c_KitKey  = @c_KitKey
         , @b_Success = @b_Success OUTPUT
         , @n_Err     = @n_Err     OUTPUT
         , @c_ErrMsg  = @c_ErrMsg  OUTPUT
      
      IF @b_Success = 0
      BEGIN   
         SET @n_Err = 560901
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Executing isp_kitReleaseTask_Wrapper. (lsp_KitReleaseTask_Wrapper)'
                        + '(' + @c_ErrMsg + ')'
         GOTO EXIT_SP               
      END

      SET @c_ErrMsg = 'Process Release Task Completed.' 
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
      IF @n_StartTCnt = 0 AND @@TRANCOUNT > @n_StartTCnt       
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

      SET @n_WarningNo = 0
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_KitReleaseTask_Wrapper'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

   IF @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END

   REVERT
END

GO