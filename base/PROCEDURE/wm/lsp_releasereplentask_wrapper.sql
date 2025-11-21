SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: lsp_ReleaseReplenTask_Wrapper                       */                                                                                  
/* Creation Date: 2021-06-24                                            */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-2868 - UATPhilippines  SCE Replenishment Module Not    */
/*          accessible                                                  */
/*                                                                      */                                                                                  
/* Called By: SCE                                                       */                                                                                  
/*          :                                                           */                                                                                  
/* PVCS Version: 1.0                                                    */                                                                                  
/*                                                                      */                                                                                  
/* Version: 8.0                                                         */                                                                                  
/*                                                                      */                                                                                  
/* Data Modifications:                                                  */                                                                                  
/*                                                                      */                                                                                  
/* Updates:                                                             */                                                                                  
/* Date        Author   Ver.  Purposes                                  */  
/* 2021-06-24  Wan      1.0   Created.                                  */
/* 2021-09-27  CheeMun  1.1   JSM-20741 - Revised script to ROLLBACK    */
/*                            if XACT_STATE() = -1                      */
/************************************************************************/                                                                                  
CREATE PROC [WM].[lsp_ReleaseReplenTask_Wrapper]                                                                                                                     
      @c_Storerkey            NVARCHAR(15) = ''  
   ,  @c_Facility             NVARCHAR(10) = ''  
   ,  @c_ReplenishStrategyKey NVARCHAR(30) = ''        
   ,  @c_ReplGroup            NVARCHAR(10) = 'ALL'  
   ,  @c_Zone02               NVARCHAR(10) = ''  
   ,  @c_Zone03               NVARCHAR(10) = ''  
   ,  @c_Zone04               NVARCHAR(10) = ''  
   ,  @c_Zone05               NVARCHAR(10) = ''  
   ,  @c_Zone06               NVARCHAR(10) = ''  
   ,  @c_Zone07               NVARCHAR(10) = ''  
   ,  @c_Zone08               NVARCHAR(10) = ''  
   ,  @c_Zone09               NVARCHAR(10) = ''  
   ,  @c_Zone10               NVARCHAR(500)= ''         
   ,  @c_Zone11               NVARCHAR(500)= ''        
   ,  @c_Zone12               NVARCHAR(10) = ''  
   ,  @c_UserName             NVARCHAR(128)= ''  
   ,  @b_Success              INT          = 1  OUTPUT     
   ,  @n_Err                  INT          = 0  OUTPUT  
   ,  @c_Errmsg               NVARCHAR(255)= '' OUTPUT  
AS  
BEGIN                                                                                                                                                        
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF       

   DECLARE  @n_StartTCnt      INT = @@TRANCOUNT  
         ,  @n_Continue       INT = 1

   SET @b_Success = 1
   SET @n_Err     = 0
               
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

   BEGIN TRY
      BEGIN TRAN        --JSM-20741
      EXEC [dbo].[ispReleaseReplenTask_Wrapper]
            @c_Facility =  @c_Facility  
         ,  @c_zone02   =  @c_zone02     
         ,  @c_zone03   =  @c_zone03   
         ,  @c_zone04   =  @c_zone04   
         ,  @c_zone05   =  @c_zone05   
         ,  @c_zone06   =  @c_zone06   
         ,  @c_zone07   =  @c_zone07   
         ,  @c_zone08   =  @c_zone08   
         ,  @c_zone09   =  @c_zone09   
         ,  @c_zone10   =  @c_zone10   
         ,  @c_zone11   =  @c_zone11   
         ,  @c_zone12   =  @c_zone12   
         ,  @c_Storerkey=  @c_Storerkey
         ,  @b_success  =  @b_success     OUTPUT  
         ,  @n_err      =  @n_err         OUTPUT  
         ,  @c_errmsg   =  @c_errmsg      OUTPUT  

      IF @b_Success <> 1
      BEGIN
         SET @n_Err = 559451
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Executing ispReleaseReplenTask_Wrapper. (lsp_ReleaseReplenTask_Wrapper)'   
                        + '(' + @c_ErrMsg + ')'  
      END 
            
   END TRY
   
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
   
EXIT_SP:
   --JSM-20741 (START)
   SELECT @c_ErrMsg '@c_ErrMsg'  
   IF XACT_STATE() = -1                                              --(Wan01)   
   BEGIN  
    ROLLBACK TRAN  
   END                                
   --JSM-20741 (END)
   
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @n_StartTCnt = 0 AND @@TRANCOUNT > @n_StartTCnt       --JSM-20741
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_ReleaseReplenTask_Wrapper'
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