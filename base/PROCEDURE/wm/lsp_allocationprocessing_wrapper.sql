SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: WM.lsp_AllocationProcessing_Wrapper                 */
/* Creation Date: 2022-02-18                                            */
/* Copyright: LFL                                                       */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: LFWM-3334 - CN NIKECN Wave control QCmdUser                 */
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
/* 2022-02-18  Wan01    1.0   Created.                                  */
/* 2022-02-18  Wan01    1.0   DevOps Combine Script.                    */
/* 2022-04-21  Wan02    1.0   LFWM-3485 - [CN] UAT Carters -Wave Control*/
/*                            - Allocation issue                        */
/* 2022-06-01  LZG      1.1   Remove BEGIN TRAN to reduce blocking(ZG01)*/
/************************************************************************/
CREATE PROC [WM].[lsp_AllocationProcessing_Wrapper]
      @c_AllocCmd             NVARCHAR(4000) = ''
   ,  @c_Wavekey              NVARCHAR(10)  = ''
   ,  @b_Success              INT = 1              OUTPUT
   ,  @n_err                  INT = 0              OUTPUT
   ,  @c_ErrMsg               NVARCHAR(255)  = ''  OUTPUT
   ,  @c_UserName             NVARCHAR(128)  = ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @n_StartTCnt            INT = @@TRANCOUNT
         ,  @n_Continue             INT = 1


   SET @b_Success = 1
   SET @n_Err     = 0

   SET @n_Err = 0
   PRINT 'NO FOUND ERROR WHILE EXECUTING WAVE PROCESSING'
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

   --BEGIN TRAN      -- ZG01
   BEGIN TRY
      EXEC ( @c_AllocCmd )
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_AllocationProcessing_Wrapper'
      RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR               --(Wan01)
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