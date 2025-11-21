SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: lsp_AssignSortLaneToOrd_Wrapper                     */                                                                                  
/* Creation Date: 2021-07-26                                            */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-2909 - UAT [CN] Missing sorting lane calculation       */
/*                                                                      */
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
/* 2021-07-26  Wan      1.0   Created.                                  */
/************************************************************************/                                                                                  
CREATE PROC [WM].[lsp_AssignSortLaneToOrd_Wrapper]                                                                                                                     
      @c_Loadkey              NVARCHAR(10) = ''  
   ,  @c_UserName             NVARCHAR(128)= ''  
   ,  @b_Success              INT          = 1  OUTPUT     
   ,  @n_Err                  INT          = 0  OUTPUT  
   ,  @c_Errmsg               NVARCHAR(255)= '' OUTPUT  
AS  
BEGIN                                                                                                                                                        
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF       

   DECLARE  @n_StartTCnt      INT = @@TRANCOUNT  
         ,  @n_Continue       INT = 1

   SET @b_Success = 1
   SET @n_Err     = 0
               
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

      EXEC [dbo].[isp_AssignSortLaneToOrd]
            @c_Loadkey =  @c_Loadkey  
         ,  @b_success  =  @b_success     OUTPUT  
         ,  @n_err      =  @n_err         OUTPUT  
         ,  @c_errmsg   =  @c_errmsg      OUTPUT  

      IF @b_Success = 0
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 559601
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Executing isp_AssignSortLaneToOrd. (lsp_AssignSortLaneToOrd_Wrapper)'   
                        + '(' + @c_Errmsg + ')'  
         GOTO EXIT_SP              
      END 
   END TRY
   
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
   
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_AssignSortLaneToOrd_Wrapper'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
  
   REVERT
END

GO