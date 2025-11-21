SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: lsp_ValidateMBOL_Wrapper                            */
/* Creation Date: 2023-07-21                                             */
/* Copyright: LFL                                                        */
/* Written by: Wan                                                       */
/*                                                                       */
/* Purpose:                                                              */
/*                                                                       */ 
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
/*************************************************************************/
CREATE   PROCEDURE [WM].[lsp_ValidateMBOL_Wrapper]
  @c_MBOLKey   NVARCHAR(10)
, @b_Success   INT           OUTPUT                   --Success:-1 Fail, 1 Pass, 2 Warning
, @n_Err       INT           OUTPUT
, @c_ErrMsg    NVARCHAR(250) OUTPUT
, @c_UserName  NVARCHAR(128) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue        INT = 1
         , @n_StartTCnt       INT = @@TRANCOUNT
         
         , @b_ReturnCode      INT = 1

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
      EXEC dbo.isp_ValidateMBOL
            @c_MBOLKey = @c_MBOLKey
         ,  @b_ReturnCode = @b_ReturnCode OUTPUT
         ,  @n_err        = @n_err        OUTPUT
         ,  @c_errmsg     = @c_errmsg     OUTPUT
         ,  @n_CBOLKey    = 0  
         ,  @c_CallFrom   = '' 
      
      IF @b_ReturnCode IN (-1,1)
      BEGIN
         SET @c_ErrMsg = 'Please refer to MBOLErrorReport for Validation Error/Warning.'
      END 
      
      IF @b_ReturnCode < 0
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_ValidateMBOL_Wrapper'
   END
   ELSE
   BEGIN
      SET @b_Success = @b_ReturnCode + 1              --@b_ReturnCode: 0-Pass, 1-Warning
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

   REVERT
END

GO