SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: lspTMPermissionAssign_Wrapper                           */
/* Creation Date: 29-NOV-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CZTENG                                                   */
/*                                                                      */
/* Purpose: call dbo.ispTMPermissionAssign                              */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2021-02-05   mingle01 1.1  Add Big Outer Begin try/Catch             */
/*                            Execute Login if @c_UserName<>SUSER_SNAME()*/ 
/************************************************************************/

CREATE PROC [WM].[lspTMPermissionAssign_Wrapper]
      @c_ProfileKey              NVARCHAR(10)
    , @c_Userkey                 NVARCHAR(18) 
    , @b_Success                 INT            = 1   OUTPUT
    , @n_Err                     INT            = 0   OUTPUT
    , @c_ErrMsg                  NVARCHAR(250)  = ''  OUTPUT
    , @n_WarningNo               INT            = 0   OUTPUT
    , @c_ProceedWithWarning      CHAR(1)        = 'N' 
    , @c_UserName                NVARCHAR(128)  = ''
    , @n_ErrGroupKey             INT            = 0   OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue           INT = 1  
         , @n_StartTCnt          INT = @@TRANCOUNT 

   SET @n_Err      = 0 
   SET @c_ErrMsg   = ''   
   SET @b_Success  = 1

   SET @n_ErrGroupKey = 0
   
   --(mingle01) - START   
   IF SUSER_SNAME() <> @c_UserName
   BEGIN
      EXEC [WM].[lsp_SetUser] 
         @c_UserName = @c_UserName  OUTPUT
       , @n_Err      = @n_Err       OUTPUT
       , @c_ErrMsg   = @c_ErrMsg    OUTPUT  
      
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
         SET @n_WarningNo = 1
         SET @c_ErrMsg =  "Do you want to assign the permission profile "+ UPPER(TRIM(@c_ProfileKey))+" to all selected users?"

         EXEC [WM].[lsp_WriteError_List]   
                  @i_iErrGroupKey= @n_ErrGroupKey OUTPUT  
               ,  @c_TableName   = 'TMPermissionProfile'  
               ,  @c_SourceType  = 'lspTMPermissionAssign_Wrapper'  
               ,  @c_Refkey1     = @c_ProfileKey  
               ,  @c_Refkey2     = @c_Userkey 
               ,  @c_Refkey3     = ''  
               ,  @c_WriteType   = 'QUESTION'  
               ,  @n_err2        = @n_err  
               ,  @c_errmsg2     = @c_errmsg  
               ,  @b_Success     = @b_Success   OUTPUT  
               ,  @n_err         = @n_err       OUTPUT  
               ,  @c_errmsg      = @c_errmsg    OUTPUT 

         IF @n_WarningNo = 1 
         BEGIN  
            GOTO EXIT_SP  
         END 
      END

      IF @c_ProceedWithWarning = 'Y'
      BEGIN

         BEGIN TRY
            EXEC [dbo].[ispTMPermissionAssign]
               @c_ProfileKey
            ,  @c_Userkey
            ,  @b_Success  OUTPUT
            ,  @n_Err      OUTPUT
            ,  @c_ErrMsg   OUTPUT
         END TRY

         BEGIN CATCH
            SET @n_err = 554951  
            SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)   
                              + ': Error Executing ispTMPermissionAssign (lspTMPermissionAssign_Wrapper)'  
                              + ' (' + @c_ErrMsg + ')' 
         END CATCH

         IF @b_Success = 0 OR @n_Err <> 0          
         BEGIN          
            SET @n_Continue = 3        
            GOTO EXIT_SP  
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
  
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lspTMPermissionAssign_Wrapper'  
      SET @n_WarningNo = 0  
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