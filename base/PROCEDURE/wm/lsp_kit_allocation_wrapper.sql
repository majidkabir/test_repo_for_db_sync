SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: lsp_Kit_Allocation_Wrapper                          */  
/* Creation Date: 2021-11-23                                             */  
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: LFWM-3162 - UAT - TW  Missing Allocation Function from       */
/*        : Kitting Module                                               */  
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/* Version: 1.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */ 
/* 2021-11-23  Wan      1.0   Created.                                   */
/* 2021-11-23  Wan      1.0   DevOps Script Combine                      */
/*************************************************************************/   
CREATE PROCEDURE [WM].[lsp_Kit_Allocation_Wrapper]  
      @c_Kitkey               NVARCHAR(10)  
   ,  @c_AllocateStrategykey  NVARCHAR(20)   = ''
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
      EXEC dbo.isp_Kit_Allocation
         @c_Kitkey               = @c_kitkey              
      ,  @c_AllocateStrategykey  = @c_AllocateStrategykey      
      ,  @b_Success              = @b_Success   OUTPUT 
      ,  @n_Err                  = @n_Err       OUTPUT
      ,  @c_Errmsg               = @c_Errmsg    OUTPUT

      IF @b_Success = 0
      BEGIN
         SET @n_Continue = 3        
         SET @n_err = 560151
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                        + ': Error Executing isp_Kit_Allocation. (lsp_Kit_Allocation_Wrapper)'
                        + '( ' + @c_ErrMsg + ' )'
         GOTO EXIT_SP
      END
      
      IF @c_ErrMsg = ''
      BEGIN
         SET @c_Errmsg = 'Allocation Completed'
      END
   END TRY
   
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE() + '. (lsp_Kit_Allocation_Wrapper)'
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_Kit_Allocation_Wrapper'
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