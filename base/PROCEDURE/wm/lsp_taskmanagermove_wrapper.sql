SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: lsp_TaskManagerMove_Wrapper                         */  
/* Creation Date: 06-SEP-2018                                            */  
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: LFWM-1149 - ABC Moves - Stored procedure for Release TM Move */
/*          Tasks                                                        */  
/*                                                                       */  
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
CREATE PROCEDURE [WM].[lsp_TaskManagerMove_Wrapper]  
   @c_StorerKey    NVARCHAR(15)
,  @c_Sku          NVARCHAR(20)
,  @c_Lot          NVARCHAR(10) = ''     
,  @c_FromLoc      NVARCHAR(10)
,  @c_FromID       NVARCHAR(18)
,  @c_ToLoc        NVARCHAR(10)
,  @c_ToID         NVARCHAR(18)
,  @n_qty          INT
,  @n_toqty        INT          = 0 
,  @c_SourceKey    NVARCHAR(30) = ''                                                  
,  @c_SourceType   NVARCHAR(30) = 'isp_TaskManagerMove'                              
,  @c_MoveMethod   NVARCHAR(2)  = 'FP'                                                 
,  @b_Success      INT          = 1   OUTPUT   
,  @n_Err          INT          = 0   OUTPUT
,  @c_Errmsg       NVARCHAR(255)= ''  OUTPUT
,  @c_UserName     NVARCHAR(128)= ''
AS  
BEGIN  
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue        INT = 1
         , @n_StartTCnt       INT = @@TRANCOUNT

         , @n_Count           INT = 0 

   SET @b_Success = 1
   SET @c_ErrMsg = ''

   SET @n_Err = 0 
   --(mingle01) - START   
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
   --(mingle01) - END
   
   --(mingle01) - START
   BEGIN TRY

      SET @c_StorerKey  = ISNULL(RTRIM(@c_StorerKey),'')         
      SET @c_Sku        = ISNULL(RTRIM(@c_Sku),'')               
      SET @c_Lot        = ISNULL(RTRIM(@c_Lot),'')               
      SET @c_FromLoc    = ISNULL(RTRIM(@c_FromLoc),'')           
      SET @c_FromID     = ISNULL(RTRIM(@c_FromID),'')            
      SET @c_ToLoc      = ISNULL(RTRIM(@c_ToLoc),'')             
      SET @c_ToID       = ISNULL(RTRIM(@c_ToID),'')              
      SET @n_qty        = ISNULL(@n_qty,0)                       
      SET @n_toqty      = ISNULL(@n_toqty,0)                     
      SET @c_SourceKey  = ISNULL(RTRIM(@c_SourceKey),'')         
      SET @c_SourceType = ISNULL(RTRIM(@c_SourceType),'')        
      SET @c_MoveMethod = ISNULL(RTRIM(@c_MoveMethod),'')        

      IF @c_SourceType = ''
      BEGIN
         SET @c_SourceType = 'isp_TaskManagerMove'
      END

      IF @c_MoveMethod = 'FP'
      BEGIN
         SET @n_toqty = @n_qty 
      END  

      IF @n_toqty = 0
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 550051
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                       + ': Move To Qty Must be greater than zero. (lsp_TaskManagerMove_Wrapper)'
                       + '( ' + @c_errmsg + ' )'
         GOTO EXIT_SP
      END

      IF EXISTS ( SELECT 1
                  FROM TASKDETAIL TD WITH (NOLOCK) 
                  WHERE TD.FromLoc = @c_FromLoc
                  AND   TD.FromID  = @c_FromID
                  AND   TD.TaskType = 'ABCMOVE'
                  AND   TD.Status IN ( '0', '3', '5')
                )
      BEGIN 
         SET @n_Continue = 3
         SET @n_err = 550052
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                       + ': Pending ABC Move task for Loc: ' + RTRIM(@c_FromLoc)
                       + ' & ID: ' + RTRIM(@c_FromID)
                       + ' is found. Release Abort. (lsp_TaskManagerMove_Wrapper)'
                       + ' |' + RTRIM(@c_FromLoc) + '|' + RTRIM(@c_FromID)
         GOTO EXIT_SP
      END

      BEGIN TRY
         EXEC isp_TaskManagerMove
            @c_StorerKey  = @c_StorerKey
         ,  @c_Sku        = @c_Sku
         ,  @c_Lot        = @c_Lot   
         ,  @c_FromLoc    = @c_FromLoc
         ,  @c_FromID     = @c_FromID
         ,  @c_ToLoc      = @c_ToLoc
         ,  @c_ToID       = @c_ToID
         ,  @n_qty        = @n_toqty
         ,  @c_SourceKey  = @c_SourceKey                                                
         ,  @c_SourceType = @c_SourceType                             
         ,  @c_MoveMethod = @c_MoveMethod                                                 
         ,  @b_Success    = @b_Success   OUTPUT   
         ,  @n_Err        = @n_Err       OUTPUT
         ,  @c_Errmsg     = @c_Errmsg    OUTPUT
      END TRY

      BEGIN CATCH
         SET @n_Continue = 3
         SET @n_err = 550053
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                       + ': Error Executing isp_TaskManagerMove. (lsp_TaskManagerMove_Wrapper)'
                       + '( ' + @c_errmsg + ' )'

         WHILE @@TRANCOUNT < @n_StartTCnt
         BEGIN 
            BEGIN TRAN
         END
      END CATCH  

      IF @b_success = 0 OR @n_Err <> 0        
      BEGIN        
         SET @n_continue = 3      
         GOTO EXIT_SP
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_TaskManagerMove_Wrapper'
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