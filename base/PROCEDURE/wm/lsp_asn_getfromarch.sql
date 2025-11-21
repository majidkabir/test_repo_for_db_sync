SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  lsp_ASN_GetFromArch                                */
/* Creation Date: 2022-10-26                                            */
/* Copyright: LFL                                                       */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: LFWM-3589 - CN-SCE-ApplySearch to Retrieve Archived ASNTrade*/ 
/*          ReturnXDock                                                 */
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
/* 2022-10-26  Created  1.0   Created & DevOps Combine Script           */
/************************************************************************/
CREATE PROC [WM].[lsp_ASN_GetFromArch]
   @c_WhereClause          NVARCHAR(MAX)
,  @b_Success              INT = 1                 OUTPUT
,  @n_err                  INT = 0                 OUTPUT
,  @c_ErrMsg               NVARCHAR(255)= ''       OUTPUT
,  @c_UserName             NVARCHAR(128) = ''                 
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @n_StartTCnt               INT = @@TRANCOUNT
         ,  @n_Continue                INT = 1

   SET @b_Success = 1
   SET @n_Err     = 0

   SET @n_Err = 0
   IF SUSER_SNAME() <> @c_UserName        
   BEGIN
      EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserName OUTPUT, @n_Err = @n_Err OUTPUT
      , @c_ErrMsg = @c_ErrMsg OUTPUT

      IF @n_Err <> 0
      BEGIN
         GOTO EXIT_SP
      END

      EXECUTE AS LOGIN = @c_UserName
   END                                

   BEGIN TRY
      EXEC dbo.isp_ASN_GetFromArch
              @c_SQLCondition       = @c_WhereClause
            , @b_Success            = @b_Success      OUTPUT
            , @n_Err                = @n_Err          OUTPUT
            , @c_ErrMsg             = @c_ErrMsg       OUTPUT
            , @b_debug              = 0

         IF @b_Success = 0 OR @n_Err <> 0
         BEGIN
            SET @n_Continue=3
            SET @n_Err = 561051
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Executing isp_ASN_GetFromArch. (lsp_ASN_GetFromArch)'
            GOTO EXIT_SP
         END
   END TRY
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg   = ERROR_MESSAGE()
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_ASN_GetFromArch'
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