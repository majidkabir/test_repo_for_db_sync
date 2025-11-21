SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Store procedure: lsp_CBOLReleaseMoveTask_Wrapper                        */
/* Creation Date: 17-Jul-2024                                              */
/* Copyright : Maersk Logistics                                            */
/* Written by: Shong                                                       */
/*                                                                         */
/* Purpose: UWP-21211 - Analysis: CBOL Migration from Exceed to MWMS V2    */
/*                                                                         */
/* Called By: MWMS Java                                                    */
/*                                                                         */
/* Version: 8.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date        Author   Ver   Purposes                                     */
/***************************************************************************/
CREATE   PROCEDURE [WM].[lsp_CBOLReleaseMoveTask_Wrapper] 
	   @c_MbolKey                 NVARCHAR(10) 
	 , @n_Cbolkey                 BIGINT = 0
    , @b_Success                 INT            = 1  OUTPUT
    , @n_Err                     INT            = 0  OUTPUT
    , @c_ErrMsg                  NVARCHAR(250)  = '' OUTPUT
    , @n_WarningNo               INT            = 0  OUTPUT
    , @c_ProceedWithWarning      CHAR(1)        = 'N'
    , @c_UserName                NVARCHAR(128)  = ''
    , @n_ErrGroupKey             INT            = 0  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue                 INT = 1
         , @n_StartTCnt                INT = @@TRANCOUNT
         , @c_TableName                NVARCHAR(50)   = 'CBOL'
         , @c_SourceType               NVARCHAR(50)   = 'lsp_CBOLReleaseMoveTask_Wrapper'
         , @c_Refkey1                  NVARCHAR(20)   = ''                   
         , @c_Refkey2                  NVARCHAR(20)   = ''                   
         , @c_Refkey3                  NVARCHAR(20)   = ''                   
         , @c_WriteType                NVARCHAR(50)   = ''                   
         , @n_LogWarningNo             INT            = 0      
         , @n_LogErrNo                 INT            = ''                   
         , @c_LogErrMsg                NVARCHAR(255)  = ''            
         , @CUR_ERRLIST                CURSOR                
         
 
   DECLARE  @t_WMSErrorList   TABLE                                  
         (  RowID             INT            IDENTITY(1,1) 
         ,  TableName         NVARCHAR(50)   NOT NULL DEFAULT('')  
         ,  SourceType        NVARCHAR(50)   NOT NULL DEFAULT('')
         ,  Refkey1           NVARCHAR(20)   NOT NULL DEFAULT('')
         ,  Refkey2           NVARCHAR(20)   NOT NULL DEFAULT('')
         ,  Refkey3           NVARCHAR(20)   NOT NULL DEFAULT('')
         ,  WriteType         NVARCHAR(50)   NOT NULL DEFAULT('')
         ,  LogWarningNo      INT            NOT NULL DEFAULT(0)
         ,  ErrCode           INT            NOT NULL DEFAULT(0)
         ,  Errmsg            NVARCHAR(255)  NOT NULL DEFAULT('')  
         )
   
   -- Switching SQL User ID from WMCOnnect to User Login ID
   SET  @n_ErrGroupKey = 0
   SET @n_Err = 0
   IF SUSER_SNAME() <> @c_UserName      
   BEGIN
      EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserName OUTPUT, @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT

      IF @n_Err <> 0
      BEGIN
         GOTO EXIT_SP
      END

      EXECUTE AS LOGIN = @c_UserName
   END                                   


   IF @n_Continue = 3
   BEGIN
      GOTO EXIT_SP
   END

   -----------------------------------------------
   -- Execute WMS Backend Stored Procedure here...
   -------------------------------------------------

   BEGIN TRAN
   IF @n_continue = 1
   BEGIN
      BEGIN TRY
         EXEC dbo.isp_CMBOLReleaseMoveTask_Wrapper  
            @c_MbolKey    = @c_MbolKey
         ,  @b_Success    = @b_Success OUTPUT
         ,  @n_Err        = @n_err      OUTPUT
         ,	@c_Errmsg     = @c_ErrMsg   OUTPUT
         ,  @n_Cbolkey    = @n_Cbolkey

      END TRY
      BEGIN CATCH
         IF (XACT_STATE()) = -1
         BEGIN
            ROLLBACK TRAN
         END

         WHILE @@TRANCOUNT < @n_StartTCNT
         BEGIN
            BEGIN TRAN
         END

         SET @n_err = 562351
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                        + ': Execute isp_CMBOLReleaseMoveTask_Wrapper Fail! (lsp_CBOLReleaseMoveTask_Wrapper )'
                        + ' (' + @c_ErrMsg + ')'
      END CATCH

      IF @b_success = 0 OR @n_Err <> 0
      BEGIN
         INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
         VALUES (@c_TableName, @c_SourceType, CAST(@n_CBOLKey AS VARCHAR(10)), @c_MBOLKey, '', 'ERROR', 0, @n_err, @c_errmsg)
            
         SET @n_Continue = 3
         GOTO EXIT_SP
      END
   END

   EXIT_SP:
   
   IF (XACT_STATE()) = -1               
   BEGIN
      SET @n_continue = 3
      ROLLBACK TRAN
   END                                  
    
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @n_StartTCnt = 1 AND @@TRANCOUNT > @n_StartTCnt              
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_CBOLReleaseMoveTask_Wrapper '
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
   

   SET @CUR_ERRLIST = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT   twl.TableName         
         ,  twl.SourceType        
         ,  twl.Refkey1           
         ,  twl.Refkey2           
         ,  twl.Refkey3           
         ,  twl.WriteType         
         ,  twl.LogWarningNo      
         ,  twl.ErrCode           
         ,  twl.Errmsg               
   FROM @t_WMSErrorList AS twl
   ORDER BY twl.RowID
   
   OPEN @CUR_ERRLIST
   
   FETCH NEXT FROM @CUR_ERRLIST INTO   @c_TableName         
                                     , @c_SourceType        
                                     , @c_Refkey1           
                                     , @c_Refkey2           
                                     , @c_Refkey3           
                                     , @c_WriteType         
                                     , @n_LogWarningNo      
                                     , @n_LogErrNo           
                                     , @c_LogErrMsg           
   
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      EXEC [WM].[lsp_WriteError_List] 
         @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
      ,  @c_TableName   = @c_TableName
      ,  @c_SourceType  = @c_SourceType
      ,  @c_Refkey1     = @c_Refkey1
      ,  @c_Refkey2     = @c_Refkey2
      ,  @c_Refkey3     = @c_Refkey3
      ,  @n_LogWarningNo= @n_LogWarningNo
      ,  @c_WriteType   = @c_WriteType
      ,  @n_err2        = @n_LogErrNo 
      ,  @c_errmsg2     = @c_LogErrMsg 
      ,  @b_Success     = @b_Success    
      ,  @n_err         = @n_err        
      ,  @c_errmsg      = @c_errmsg         
     
      FETCH NEXT FROM @CUR_ERRLIST INTO   @c_TableName         
                                        , @c_SourceType        
                                        , @c_Refkey1           
                                        , @c_Refkey2           
                                        , @c_Refkey3           
                                        , @c_WriteType         
                                        , @n_LogWarningNo      
                                        , @n_LogErrNo           
                                        , @c_LogErrmsg     
   END
   CLOSE @CUR_ERRLIST
   DEALLOCATE @CUR_ERRLIST
   
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
   
   REVERT
END -- End Procedure

GO