SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: lsp_MoveToPALoc_Wrapper                             */                                                                                  
/* Creation Date: 2021-06-30                                            */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-2849 - UAT - TW  Receipt  Trade Return Missing Function*/
/*           Move to Putaway Location                                   */
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
/* 2021-06-30  Wan      1.0   Created.                                  */
/* 2021-10-28  Wan      1.0   DevOps Script Combine                      */
/************************************************************************/                                                                                  
CREATE PROC [WM].[lsp_MoveToPALoc_Wrapper]                                                                                                                     
      @c_ReceiptKey           NVARCHAR(10) = ''  
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

   BEGIN TRAN
   
   BEGIN TRY
      EXEC [dbo].[nspMovetoPutawayLoc]
            @c_Receiptkey =  @c_Receiptkey
         ,  @b_success    =  @b_success     OUTPUT  
         ,  @n_err        =  @n_err         OUTPUT  
         ,  @c_errmsg     =  @c_errmsg      OUTPUT  

      IF @b_Success <> 1
      BEGIN
         SET @n_Err = 559501
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Executing nspMovetoPutawayLoc. (lsp_MoveToPALoc_Wrapper)'   
                        + '(' + @c_ErrMsg + ')'  
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
      IF  @@TRANCOUNT = 0 AND @@TRANCOUNT > @n_StartTCnt
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_MoveToPALoc_Wrapper'
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