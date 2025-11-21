SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: lsp_WaveLoadDetail_Delete                           */                                                                                  
/* Creation Date: 2019-10-04                                            */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-1909 - Stored procedures for Load Delete               */
/*          & Ship Ref Unit Delete                                      */
/*                                                                      */      
/* Called By: SCE                                                       */                                                                                  
/*          :                                                           */                                                                                  
/* PVCS Version: 1.2                                                    */                                                                                  
/*                                                                      */                                                                                  
/* Version: 8.0                                                         */                                                                                  
/*                                                                      */                                                                                  
/* Data Modifications:                                                  */                                                                                  
/*                                                                      */                                                                                  
/* Updates:                                                             */                                                                                  
/* Date        Author   Ver.  Purposes                                  */  
/* 04-Jan-2021 SWT02    1.1   Do not execute login if user already      */
/*                            changed                                   */
/* 2021-02-25  Wan01    1.2   Add Big Outer Try/Catch                   */
/************************************************************************/                                                                                  
CREATE PROC [WM].[lsp_WaveLoadDetail_Delete] 
      @c_LoadKey              NVARCHAR(10)                                                                                                                    
   ,  @c_LoadLineNumber       NVARCHAR(10)  = ''        
   ,  @n_TotalSelectedKeys    INT = 1
   ,  @n_KeyCount             INT = 1                 OUTPUT
   ,  @b_Success              INT = 1                 OUTPUT  
   ,  @n_err                  INT = 0                 OUTPUT                                                                                                             
   ,  @c_ErrMsg               NVARCHAR(255)= ''       OUTPUT 
   ,  @n_WarningNo            INT          = 0        OUTPUT
   ,  @c_ProceedWithWarning   CHAR(1)      = 'N'                     
   ,  @c_UserName             NVARCHAR(128)= ''                                                                                                                         
   ,  @n_ErrGroupKey          INT          = 0        OUTPUT
AS  
BEGIN                                                                                                                                                        
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF       

   DECLARE  @n_StartTCnt      INT = @@TRANCOUNT  
         ,  @n_Continue       INT = 1

         ,  @b_Deleted        BIT = 0
         ,  @b_ReturnCode     INT = 0
  
         ,  @c_TableName      NVARCHAR(50)   = 'LOADPLANDETAIL'
         ,  @c_SourceType     NVARCHAR(50)   = 'lsp_WaveLoadDetail_Delete'

         ,  @CUR_DETAIL         CURSOR
   SET @b_Success = 1
   SET @n_Err     = 0
               

   -- SWT02 --Wan01 Move UP
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
      
      IF @n_ErrGroupKey IS NULL
      BEGIN 
         SET @n_ErrGroupKey = 0
      END
 
      BEGIN TRY
         DELETE FROM LOADPLANDETAIL
         WHERE Loadkey = @c_Loadkey
         AND  LoadLineNumber = @c_LoadLineNumber
      END TRY

      BEGIN CATCH
         SET @n_Err = 557201
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Delete Loadplandetail Fail. (lsp_WaveLoadDetail_Delete)'   
                        + '(' + @c_ErrMsg + ')' 

         IF (XACT_STATE()) = -1  
         BEGIN
            ROLLBACK TRAN

            WHILE @@TRANCOUNT < @n_StartTCnt
            BEGIN
               BEGIN TRAN
            END
         END 

         EXEC [WM].[lsp_WriteError_List] 
               @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
            ,  @c_TableName   = @c_TableName
            ,  @c_SourceType  = @c_SourceType
            ,  @c_Refkey1     = @c_LoadKey
            ,  @c_Refkey2     = @c_LoadLineNumber
            ,  @c_Refkey3     = ''
            ,  @c_WriteType   = 'ERROR' 
            ,  @n_err2        = @n_err 
            ,  @c_errmsg2     = @c_errmsg 
            ,  @b_Success     = @b_Success   OUTPUT 
            ,  @n_err         = @n_err       OUTPUT 
            ,  @c_errmsg      = @c_errmsg    OUTPUT

         GOTO EXIT_SP
      END CATCH
   END TRY
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
 
EXIT_SP:
   IF @b_Deleted = 1
   BEGIN     
      IF @n_KeyCount = @n_TotalSelectedKeys
      BEGIN
         SET @c_ErrMsg = 'Delete Loadplan detail is/are done.'

         IF @n_ErrGroupKey > 0 
         BEGIN
            SET @n_Continue = 3
            SET @c_ErrMsg = 'Process Delete Selected Loadplan Detail is/are done with error(s).'
         END
      END

      IF @n_KeyCount < @n_TotalSelectedKeys
      BEGIN
         SET @n_KeyCount = @n_KeyCount + 1

         IF @n_ErrGroupKey > 0 AND  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
         BEGIN
            ROLLBACK TRAN
         END
      END
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
      SET @n_WarningNo = 0
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_WaveLoadDetail_Delete'
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