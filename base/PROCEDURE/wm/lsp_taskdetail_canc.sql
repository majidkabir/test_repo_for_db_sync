SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: lsp_TaskDetail_Canc                                 */  
/* Creation Date: 2022-09-27                                             */ 
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: LFWM-3607 - [CN]NIKE_Cancel Task By whole search result      */
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/*                                                                       */  
/* Version: 1.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */ 
/* 2022-09-27  Wan      1.0   Created & DevOps Combine Script            */
/*************************************************************************/   
CREATE   PROCEDURE [WM].[lsp_TaskDetail_Canc]  
   @c_TaskDetailKeys       NVARCHAR(4000)= ''         --if Not cancel by Search Criteria, pass in all ticked Taskdetailkey seperated by '|'
,  @c_WhereClause          NVARCHAR(MAX)= ''          --If cancel by Search Criteria; pass in WHERE Condition for eg. TASKDETAIL.Storerkey = 'XXX' 
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

   DECLARE @n_Continue           INT = 1
         , @n_StartTCnt          INT = @@TRANCOUNT

         , @c_TaskdetailKey_Upd  NVARCHAR(10)   = ''
         , @c_SQL                NVARCHAR(4000) = ''
         , @c_SQLCondition       NVARCHAR(2000) = ''

   SET @b_Success = 1
   SET @c_ErrMsg = ''
   SET @n_Err = 0

   IF OBJECT_ID('tempdb..#TASKCANC', 'u') IS NOT NULL
   BEGIN
      DROP TABLE #TASKCANC;
   END
   
   CREATE TABLE #TASKCANC 
      (
         TaskDetailKey  NVARCHAR(10)   NOT NULL DEFAULT('') PRIMARY KEY
      )
   
   IF ISNULL(@c_UserName,'') <> ''
   BEGIN
      IF SUSER_SNAME() <> @c_UserName
      BEGIN 
         EXEC [WM].[lsp_SetUser] 
                  @c_UserName = @c_UserName  OUTPUT 
               ,  @n_Err      = @n_Err       OUTPUT
               ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT
                   
         EXECUTE AS LOGIN = @c_UserName
      END
   END

   BEGIN TRY
      IF @c_TaskDetailKeys = ''
      BEGIN
         SET @c_SQL = N'SELECT TaskDetail.TaskDetailKey'
                    + ' FROM dbo.TaskDetail WITH (NOLOCK)'
                    + ' LEFT JOIN dbo.SKU WITH (NOLOCK) ON TaskDetail.Storerkey = SKU.Storerkey'
                    +                                 ' AND TaskDetail.Sku = SKU.Sku'
                    + ' LEFT OUTER JOIN dbo.LOC WITH (NOLOCK) ON TaskDetail.fromloc = LOC.loc'
                    + ' LEFT JOIN dbo.ID WITH (NOLOCK) ON ID.ID=TaskDetail.FromID'
                    + ' ' + @c_WhereClause
                    + ' ORDER BY TaskDetail.TaskDetailKey'
         
         INSERT INTO #TASKCANC (TaskDetailKey)
         EXEC sp_ExecuteSQL @c_SQL              
      END
      ELSE
      BEGIN
         INSERT INTO #TASKCANC (TaskDetailKey)
         SELECT ss.Value FROM STRING_SPLIT(@c_TaskDetailKeys, '|') AS ss
         --VALUES (@c_TaskDetailKey)
      END
      
      SET @c_TaskdetailKey_Upd = ''
      WHILE 1 = 1
      BEGIN
         SELECT TOP 1 @c_TaskdetailKey_Upd = t.TaskDetailKey
         FROM #TASKCANC AS t
         WHERE t.TaskDetailKey > @c_TaskdetailKey_Upd
         ORDER BY t.TaskDetailKey
         
         IF @@ROWCOUNT = 0
         BEGIN
            BREAK
         END
         
         UPDATE TASKDETAIL WITH (ROWLOCK)
         SET [Status] = 'X'
          ,EditWho  = SUSER_SNAME()
          ,EditDate = GETDATE()
         WHERE TaskDetailKey = @c_TaskdetailKey_Upd
      
         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 560951
            SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6),@n_Err) + ': Update Taskdetail fail. (lsp_TaskDetail_Canc)'
            GOTO EXIT_SP
         END
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_TaskDetail_Canc'
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