SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: lsp_GetGTMKioskJobs_Wrapper                         */  
/* Creation Date: 28-FEB-2019                                            */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose:                                                              */  
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
/* 2021-02-05   mingle01 1.1  Add Big Outer Begin try/Catch             */
/*                            Execute Login if @c_UserName<>SUSER_SNAME()*/
/*************************************************************************/   
CREATE PROCEDURE [WM].[lsp_GetGTMKioskJobs_Wrapper]  
   @c_GTMWorkStation NVARCHAR(10) 
,  @c_JobKey         NVARCHAR(10)        OUTPUT
,  @c_TaskDetailKey  NVARCHAR(10)        OUTPUT
,  @c_ID             NVARCHAR(18)        OUTPUT
,  @c_PickToID       NVARCHAR(18)        OUTPUT
,  @c_PanelLUOClass  NVARCHAR(60)        OUTPUT
,  @c_PanelMUOClass  NVARCHAR(60)        OUTPUT
,  @c_PanelRUOClass  NVARCHAR(60)        OUTPUT
,  @b_Scheduler      INT = 0             OUTPUT
,  @b_Success        INT          = 1    OUTPUT   
,  @n_Err            INT          = 0    OUTPUT
,  @c_Errmsg         NVARCHAR(255)= ''   OUTPUT
,  @c_UserName       NVARCHAR(128)= ''
AS  
BEGIN  
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @n_Continue     INT = 1
         , @n_StartTCnt    INT = @@TRANCOUNT 
                 
         , @n_Count        INT = 0 

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

      BEGIN TRY
         EXEC dbo.isp_GetGTMKioskJobs
            @c_GTMWorkStation = @c_GTMWorkStation
         ,  @c_JobKey         = @c_JobKey          OUTPUT
         ,  @c_TaskDetailKey  = @c_TaskDetailKey   OUTPUT
         ,  @c_ID             = @c_ID              OUTPUT
         ,  @c_PickToID       = @c_PickToID        OUTPUT
         ,  @c_PanelLUOClass  = @c_PanelLUOClass   OUTPUT
         ,  @c_PanelMUOClass  = @c_PanelMUOClass   OUTPUT
         ,  @c_PanelRUOClass  = @c_PanelRUOClass   OUTPUT
         ,  @b_Scheduler      = @b_Scheduler       OUTPUT
         ,  @b_Success        = @b_Success         OUTPUT 
         ,  @n_Err            = @n_Err             OUTPUT
         ,  @c_Errmsg         = @c_Errmsg          OUTPUT

      END TRY
      BEGIN CATCH
         SET @n_err = 555401
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                        + ': Error Executing isp_GetGTMKioskJobs. (lsp_GetGTMKioskJobs_Wrapper)'
                        + '( ' + @c_ErrMsg + ' )'
      END CATCH

      IF @b_Success = 0 OR @n_Err <> 0 
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
   
   IF @n_Continue = 3   
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_GetGTMKioskJobs_Wrapper'
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