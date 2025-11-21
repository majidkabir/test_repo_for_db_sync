SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: lsp_WaveMbol_Delete                                 */                                                                                  
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
/* 29-Dec-2020 SWT01    1.1   Add Big Outer Begin Try.End Try to enable */
/*                             Revert when Sub SP Raise error           */
/* 15-Jan-2021 Wan01    1.2   Execute Login if @c_UserName<>SUSER_SNAME()*/
/************************************************************************/                                                                                  
CREATE PROC [WM].[lsp_WaveMbol_Delete] 
      @c_MBOLKey              NVARCHAR(10)                                                                                                                    
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

   DECLARE  @n_StartTCnt               INT = @@TRANCOUNT  
         ,  @n_Continue                INT = 1

         ,  @b_Deleted                 BIT = 0
         ,  @n_TotalSelectedKeys_Det   INT = 0
         ,  @n_KeyCount_Det            INT = 1

         ,  @c_MBolLineNumber          NVARCHAR(10)   = ''     
         ,  @c_TableName               NVARCHAR(50)   = 'MBOL'
         ,  @c_SourceType              NVARCHAR(50)   = 'lsp_WaveMbol_Delete'

         ,  @CUR_DETAIL                CURSOR
   SET @b_Success = 1
   SET @n_Err     = 0
               
   IF @c_ProceedWithWarning = 'N' AND @n_WarningNo < 1
   BEGIN
      SET @n_WarningNo = 1
      
      SET @c_ErrMsg = 'Delete Selected Ship Ref Unit?' 

      GOTO EXIT_SP
   END
   
   IF SUSER_SNAME() <> @c_UserName  --(Wan01) - START
   BEGIN
      SET @n_Err = 0 
      EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserName OUTPUT, @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT --(Wan01)
   
      EXECUTE AS LOGIN=@c_UserName -- (SWT01) 
   END                              --(Wan01) - END
   
   BEGIN TRY -- (SWT01)
   
      SET @n_ErrGroupKey = 0

      SELECT @n_TotalSelectedKeys_Det = COUNT(1)
      FROM MBOLDETAIL MD WITH (NOLOCK)
      WHERE MD.MBOLKey = @c_MBOLKey

      SET @CUR_DETAIL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT MD.MBolLineNumber
      FROM MBOLDETAIL MD WITH (NOLOCK)
      WHERE MD.MBOLKey = @c_MBOLKey
      ORDER BY MD.MBolLineNumber

      OPEN @CUR_DETAIL
   
      FETCH NEXT FROM @CUR_DETAIL INTO @c_MBolLineNumber                                                                                
                                    
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @b_Deleted = 1
         SET @c_ErrMsg  = ''
         EXEC [WM].[lsp_WaveMBolDetail_Delete]  
              @c_MBOLKey            = @c_MBOLKey                                                                                                                         
            , @c_MBolLineNumber     = @c_MBolLineNumber             
            , @n_TotalSelectedKeys  = @n_TotalSelectedKeys_Det
            , @n_KeyCount           = @n_KeyCount_Det OUTPUT
            , @b_Success            = @b_Success      OUTPUT
            , @n_Err                = @n_Err          OUTPUT 
            , @c_ErrMsg             = @c_ErrMsg       OUTPUT 
            , @n_WarningNo          = 1        
            , @c_ProceedWithWarning = 'Y'                     
            , @c_UserName           = @c_UserName
            , @n_ErrGroupKey        = @n_ErrGroupKey  OUTPUT

         IF @b_Success = 0 OR @n_Err <> 0
         BEGIN
            SET @n_Continue=3
            SET @n_Err = 557251
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Executing lsp_WaveMBolDetail_Delete. (lsp_WaveMbol_Delete)'   
                    
            EXEC [WM].[lsp_WriteError_List] 
                  @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
               ,  @c_TableName   = @c_TableName
               ,  @c_SourceType  = @c_SourceType
               ,  @c_Refkey1     = @c_MBOLKey
               ,  @c_Refkey2     = @c_MBolLineNumber
               ,  @c_Refkey3     = ''
               ,  @c_WriteType   = 'ERROR' 
               ,  @n_err2        = @n_err 
               ,  @c_errmsg2     = @c_errmsg 
               ,  @b_Success     = @b_Success   OUTPUT 
               ,  @n_err         = @n_err       OUTPUT 
               ,  @c_errmsg      = @c_errmsg    OUTPUT

         END
         FETCH NEXT FROM @CUR_DETAIL INTO @c_MBolLineNumber 
      END
      CLOSE @CUR_DETAIL
      DEALLOCATE @CUR_DETAIL

      IF NOT EXISTS (   SELECT 1  
                        FROM MBOLDETAIL MD WITH (NOLOCK)
                        WHERE MD.MBOLKey = @c_MBOLKey
                     )
      BEGIN
         BEGIN TRY  
            DELETE FROM MBOL  
            WHERE MBOLKey = @c_MBOLKey  
         END TRY  
  
         BEGIN CATCH
            SET @n_Continue=3        
            SET @n_Err = 557252 
            SET @c_ErrMsg = ERROR_MESSAGE()  
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Delete MBol Fail. (lsp_WaveMbol_Delete)'     
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
               ,  @c_Refkey1     = @c_MBOLKey
               ,  @c_Refkey2     = '' 
               ,  @c_Refkey3     = ''
               ,  @c_WriteType   = 'ERROR' 
               ,  @n_err2        = @n_err 
               ,  @c_errmsg2     = @c_errmsg 
               ,  @b_Success     = @b_Success   OUTPUT 
               ,  @n_err         = @n_err       OUTPUT 
               ,  @c_errmsg      = @c_errmsg    OUTPUT
         END CATCH  
      END
   END TRY -- (SWT01)

   BEGIN CATCH
      SET @n_Continue = 3              --(Wan01)
      SET @c_ErrMsg   = ERROR_MESSAGE()--(Wan01)
      GOTO EXIT_SP
   END CATCH    
   
EXIT_SP:
   IF @b_Deleted = 1 
   BEGIN     
      IF @n_KeyCount = @n_TotalSelectedKeys
      BEGIN
         SET @c_ErrMsg = 'Delete Selected Ship Ref Unit is/are done.'

         IF @n_ErrGroupKey > 0 
         BEGIN
            SET @n_Continue = 3
            SET @c_ErrMsg = 'Process Delete Selected Ship Ref Unit is/are done with error(s).'
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_WaveMbol_Delete'
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