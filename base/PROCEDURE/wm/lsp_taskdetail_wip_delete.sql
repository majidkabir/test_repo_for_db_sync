SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: lsp_TaskDetail_WIP_Delete                           */  
/* Creation Date: 20-SEP-2018                                            */  
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: LFWM-1273 - Stored Procedures for Feature ¿C Release Cycle    */
/*          Count                                                        */  
/* Called By:                                                            */  
/*                                                                       */  
/*                                                                       */  
/* Version: 1.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */ 
/* 2021-02-09   mingle01 1.1  Add Big Outer Begin try/Catch              */
/*                            Execute Login if @c_UserName<>SUSER_SNAME()*/
/*************************************************************************/   
CREATE PROCEDURE [WM].[lsp_TaskDetail_WIP_Delete]
   @c_BatchNo              NVARCHAR(10)  
,  @b_Success              INT          = 1   OUTPUT   
,  @n_Err                  INT          = 0   OUTPUT
,  @c_Errmsg               NVARCHAR(255)= ''  OUTPUT
,  @c_UserName             NVARCHAR(128)= ''

AS  
BEGIN  
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue        INT = 1
         , @n_StartTCnt       INT = @@TRANCOUNT

         , @n_RowId           BIGINT = 0
         , @n_LogKey          BIGINT = 0

         , @CUR_DEL           CURSOR

   SET @b_Success = 1
   SET @c_ErrMsg = ''
   SET @n_Err = 0
   
   IF ISNULL(@c_UserName,'') <> ''
   BEGIN
   --(mingle01) - START   
      IF SUSER_SNAME() <> @c_UserName
      BEGIN 
         EXEC [WM].[lsp_SetUser] 
                  @c_UserName = @c_UserName  OUTPUT 
               ,  @n_Err      = @n_Err       OUTPUT
               ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT
                   
         EXECUTE AS LOGIN = @c_UserName
      END
   END
   --(mingle01) - END
   
   --(mingle01) - START
   BEGIN TRY
      SET @CUR_DEL = CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT RowID
      FROM TASKDETAIL_WIP WITH (NOLOCK)
      WHERE TaskWIPBatchNo = @c_BatchNo

      OPEN @CUR_DEL
      
      FETCH NEXT FROM @CUR_DEL INTO @n_RowID
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         BEGIN TRY
            DELETE TASKDETAIL_WIP
            WHERE RowID = @n_RowID
         END TRY

         BEGIN CATCH
            SET @n_Continue = 3
            SET @n_err = 554751
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Delete from TASKDETAIL_WIP Fail. (lsp_TaskDetail_WIP_Delete)'
                           + '( ' + @c_errmsg + ' )'

            GOTO EXIT_SP
         END CATCH  
         FETCH NEXT FROM @CUR_DEL INTO @n_RowID        
      END
      CLOSE @CUR_DEL 
      DEALLOCATE @CUR_DEL

      SELECT @n_LogKey = LogKey
      FROM IDS_GENERALLOG WITH (NOLOCK)
      WHERE udf01 = 'SKURELOPTION'
      AND   udf02 = @c_BatchNo 

      IF @n_LogKey > 0 
      BEGIN
         BEGIN TRY
            DELETE IDS_GENERALLOG WHERE LogKey = @n_LogKey
         END TRY

         BEGIN CATCH
            SET @n_Continue = 3
            SET @n_err = 554752
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Delete From IDS_GeneralLog Fail. (lsp_TaskDetail_WIP_Delete)'
                           + '( ' + @c_errmsg + ' )'

            GOTO EXIT_SP
         END CATCH  
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_TaskDetail_WIP_Delete'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

   IF ISNULL(@c_UserName,'') <> ''
   BEGIN
      REVERT  
   END    
END  

GO