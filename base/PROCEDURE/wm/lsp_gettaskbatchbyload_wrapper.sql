SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: lsp_GetTaskBatchByLoad_Wrapper                      */  
/* Creation Date: 2021-09-22                                             */  
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: LFWM-3057 - Add in a new tab in wave control to only show the*/ 
/*        :ecom order replenishment based on selected load keys          */ 
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/*                                                                       */  
/* Version: 1.1                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */ 
/* 2021-09-22  Wan      1.0   Created.                                   */
/* 2021-09-22  Wan      1.0   DevOps Combine Script                      */
/* 2022-10-17  Wan01    1.1   LFWM-3813 - SCE  LOREAL PROD  Wave Control */
/*                            Cannot display more than 11 load detail lines*/
/*                            SP changes.                                */
/*************************************************************************/   
CREATE   PROCEDURE [WM].[lsp_GetTaskBatchByLoad_Wrapper]  
     @c_Loadkeys  NVARCHAR(1000) = ''  -- Multiple loadkeys will seperate by '|' --(Wan01) - extend to 1000     
   , @c_UserName  NVARCHAR(128)  = ''
   , @b_Success   INT            = 0   OUTPUT    
   , @n_err       INT            = 0   OUTPUT
   , @c_errmsg    NVARCHAR(255)  = ''  OUTPUT
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

   BEGIN TRY
      EXEC dbo.isp_GetEOrder_TaskBatch
         @c_Loadkey    = @c_Loadkeys         
   END TRY
   
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE() + '. (lsp_GetTaskBatchByLoad_Wrapper)'

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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_GetTaskBatchByLoad_Wrapper'
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
END  

GO