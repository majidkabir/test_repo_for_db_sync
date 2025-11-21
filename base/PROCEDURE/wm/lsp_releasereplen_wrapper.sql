SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: lsp_ReleaseReplen_Wrapper                           */  
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
/* 2021-02-09   mingle01 1.1  Add Big Outer Begin try/Catch              */
/*                            Execute Login if @c_UserName<>SUSER_SNAME()*/
/*************************************************************************/   
CREATE PROCEDURE [WM].[lsp_ReleaseReplen_Wrapper]  
   @c_Facility             NVARCHAR(10) = ''
,  @c_Zone02               NVARCHAR(10) = ''
,  @c_Zone03               NVARCHAR(10) = ''
,  @c_Zone04               NVARCHAR(10) = ''
,  @c_Zone05               NVARCHAR(10) = ''
,  @c_Zone06               NVARCHAR(10) = ''
,  @c_Zone07               NVARCHAR(10) = ''
,  @c_Zone08               NVARCHAR(10) = ''
,  @c_Zone09               NVARCHAR(10) = ''
,  @c_Zone10               NVARCHAR(10) = ''
,  @c_Zone11               NVARCHAR(10) = ''
,  @c_Zone12               NVARCHAR(10) = ''
,  @c_Storerkey            NVARCHAR(15) = ''
,  @c_ReplGroup            NVARCHAR(10) = 'ALL'
,  @b_Success              INT          = 1   OUTPUT   
,  @n_Err                  INT          = 0   OUTPUT
,  @c_Errmsg               NVARCHAR(255)= ''  OUTPUT
,  @n_WarningNo            INT          = 0   OUTPUT
,  @c_ProceedWithWarning   CHAR(1)      = 'N' 
,  @c_UserName             NVARCHAR(128)= ''
AS  
BEGIN  
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
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

      IF ISNULL(RTRIM(@c_Facility),'') = ''
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 555301
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Facility cannot be blank. (lsp_ReleaseReplen_Wrapper)'
         GOTO EXIT_SP
      END
       
      IF @c_ProceedWithWarning = 'N' AND @n_WarningNo < 1
      BEGIN
         SET @n_WarningNo = 1
         SET @c_ErrMsg = 'Do you want to release Replenishment Task?'
         GOTO EXIT_SP     
      END  
      

      BEGIN TRY
         EXEC dbo.ispReleaseReplenTask_Wrapper
            @c_Zone01 = @c_Facility      
         ,  @c_Zone02 = @c_Zone02       
         ,  @c_Zone03 = @c_Zone03        
         ,  @c_Zone04 = @c_Zone04        
         ,  @c_Zone05 = @c_Zone05        
         ,  @c_Zone06 = @c_Zone06        
         ,  @c_Zone07 = @c_Zone07        
         ,  @c_Zone08 = @c_Zone08        
         ,  @c_Zone09 = @c_Zone09        
         ,  @c_Zone10 = @c_Zone10        
         ,  @c_Zone11 = @c_Zone11        
         ,  @c_Zone12 = @c_Zone12 
         ,  @c_Storerkey= @c_Storerkey 
         ,  @b_Success  = @b_Success   OUTPUT 
         ,  @n_Err      = @n_Err       OUTPUT
         ,  @c_Errmsg   = @c_Errmsg    OUTPUT

      END TRY
      BEGIN CATCH
         IF (XACT_STATE()) = -1  
         BEGIN
            ROLLBACK TRAN

            WHILE @@TRANCOUNT < @n_StartTCnt
            BEGIN
               BEGIN TRAN
            END
         END  

         SET @n_err = 555302
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                        + ': Error Executing ispReleaseReplenTask_Wrapper. (lsp_ReleaseReplen_Wrapper)'
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_ReleaseReplen_Wrapper'
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