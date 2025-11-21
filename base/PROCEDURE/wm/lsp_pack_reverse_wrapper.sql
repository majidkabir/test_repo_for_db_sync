SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: lsp_Pack_Reverse_Wrapper                            */  
/* Creation Date: 2023-04-17                                             */  
/* Copyright: Maersk                                                     */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: LFWM-4089 - [CN] CONVERSE_PACK_MANAGEMENT_BUG                */
/*        :                                                              */  
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/* Version: 1.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */ 
/* 2023-04-17  Wan      1.0   Created.                                   */
/* 2023-04-17  Wan      1.0   DevOps Script Combine                      */
/*************************************************************************/   
CREATE   PROCEDURE [WM].[lsp_Pack_Reverse_Wrapper]  
      @c_PickSlipNo           NVARCHAR(10)  
   ,  @b_Success              INT            = 1   OUTPUT   
   ,  @n_Err                  INT            = 0   OUTPUT
   ,  @c_Errmsg               NVARCHAR(255)  = ''  OUTPUT
   ,  @c_UserName             NVARCHAR(128)  = ''
AS  
BEGIN  
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue     INT = 1
         , @n_StartTCnt    INT = @@TRANCOUNT 
                 
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
   
   BEGIN TRAN

   BEGIN TRY
      IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader AS ph WITH (NOLOCK) 
                     WHERE ph.PickSlipNo = @c_PickSlipNo AND ph.[Status] = '9')
      BEGIN
         SET @n_Continue = 3  
         SET @n_Err = 561551
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': PickSlipNo: ' + @c_PickSlipNo  
                       + ' has not pack confirmed yet. (lsp_Pack_Reverse_Wrapper) |' + @c_PickSlipNo   
         GOTO EXIT_SP   
      END
      
      EXEC  isp_UnpackReversal  
            @c_PickSlipNo  = @c_PickSlipNo  
         ,  @c_UnpackType  = 'R'  
         ,  @b_Success     = @b_Success   OUTPUT   
         ,  @n_err         = @n_err       OUTPUT   
         ,  @c_errmsg      = @c_errmsg    OUTPUT  
      
      IF @b_Success = 0
      BEGIN
         SET @n_Continue = 3        
         GOTO EXIT_SP
      END

     
      IF @c_ErrMsg = ''
      BEGIN
         SET @c_Errmsg = 'Reverse is Completed.'
      END
   END TRY
   
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE() + '. (lsp_Pack_Reverse_Wrapper)'
      GOTO EXIT_SP
   END CATCH

   EXIT_SP:
      
   IF (XACT_STATE()) = -1  
   BEGIN
      SET @n_Continue = 3 
      ROLLBACK TRAN
   END  
   
   IF @n_Continue = 3   
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_Pack_Reverse_Wrapper'
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