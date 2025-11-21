SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: lsp_RCMConfigSP_WAVE_Wrapper                        */  
/* Creation Date: 2020-06-11                                             */  
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: LFWM-2159 - Dyanamic Menu RCMConfig PO                       */
/*          ReceiptTransferSOAdjustmentWaveLoadPlanMbol                  */
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
/* 2021-02-09  mingle01 1.1   Add Big Outer Begin try/Catch              */
/*                            Execute Login if @c_UserName<>SUSER_SNAME()*/ 
/* 2021-07-05  Wan01    1.2   LFWM-2875 - UAT RG-Create RCM allocation   */
/*                            feature in Adjustment Screen- SCE          */
/* 2025-02-19  SSA01    1.3   Infinity Loop in Commiting Transaction     */
/*                            DevOps Combine Script                      */
/*************************************************************************/
CREATE   PROCEDURE [WM].[lsp_RCMConfigSP_WAVE_Wrapper]
   @c_Storerkey   NVARCHAR(15)
,  @c_WaveKey     NVARCHAR(10) 
,  @b_Success     INT          = 1   OUTPUT   
,  @n_Err         INT          = 0   OUTPUT
,  @c_Errmsg      NVARCHAR(255)= ''  OUTPUT
,  @c_UserName    NVARCHAR(128)= ''
,  @c_Code        NVARCHAR(30) = ''           --(Wan01) Extended to 30
AS  
BEGIN  
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue        INT = 1
         , @n_StartTCnt       INT = @@TRANCOUNT

         , @n_Count           INT = 0 
         , @c_RCMConfigSP     NVARCHAR(60) = ''

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
      WHILE  @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END

      BEGIN TRAN

      SELECT @c_RCMConfigSP = RTRIM(CL.Long)
      FROM CODELKUP CL (NOLOCK)
      WHERE CL.ListName = 'RCMConfig'
      AND   CL.Code = @c_Code
      AND   CL.UDF01= 'wave'
      AND   CL.Short= 'storedproc'
      AND   CL.Storerkey = @c_Storerkey

      IF @c_RCMConfigSP <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM sys.objects (NOLOCK) WHERE Object_ID(@c_RCMConfigSP) = object_id AND [Type] = 'P')
         BEGIN
            GOTO EXIT_SP
         END
      END

      BEGIN TRY   
         SET @b_Success = 1
          
         EXEC @c_RCMConfigSP 
            @c_Wavekey        = @c_Wavekey
         ,  @b_Success        = @b_Success   OUTPUT
         ,  @n_Err            = @n_Err       OUTPUT  
         ,  @c_ErrMsg         = @c_ErrMsg    OUTPUT   
         ,  @c_Code           = @c_Code        

      END TRY

      BEGIN CATCH
         SET @n_Continue = 3
         SET @n_err = 558201
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error Executing Wave''s RCMConfig Custom SP' + @c_RCMConfigSP + '. (lsp_RCMConfigSP_WAVE_Wrapper)'
                        + '( ' + @c_errmsg + ' ) |' + @c_RCMConfigSP
      END CATCH    
      
      IF @n_err <> 0 
      BEGIN
         SET @n_Continue = 3
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
   --(SSA01) - START
   IF (XACT_STATE()) = -1
   BEGIN
      SET @n_Continue = 3
      ROLLBACK TRAN
   END
   --(SSA01) - END

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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_RCMConfigSP_WAVE_Wrapper'
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