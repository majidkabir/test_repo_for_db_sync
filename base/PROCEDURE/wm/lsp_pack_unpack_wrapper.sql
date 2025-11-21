SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: lsp_Pack_Unpack_Wrapper                             */  
/* Creation Date: 2021-12-24                                             */  
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: LFWM-3259 - UAT RG  Unpack function and pack management      */
/*        : changes                                                      */  
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/* Version: 1.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */ 
/* 2021-12-24  Wan      1.0   Created.                                   */
/* 2021-12-24  Wan      1.0   DevOps Script Combine                      */
/* 2022-01-28  Wan      1.0   #LFWM3259-Defect-Pack Header should not be */
/*                            deleted                                    */                                  
/*************************************************************************/   
CREATE PROCEDURE [WM].[lsp_Pack_Unpack_Wrapper]  
      @c_PickSlipNo           NVARCHAR(10)  
   ,  @c_LabelNo              NVARCHAR(20)   
   ,  @b_Success              INT            = 1   OUTPUT   
   ,  @n_Err                  INT            = 0   OUTPUT
   ,  @c_Errmsg               NVARCHAR(255)  = ''  OUTPUT
   ,  @c_UserName             NVARCHAR(128)  = ''
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
   
   BEGIN TRAN

   BEGIN TRY
      IF EXISTS (SELECT 1 FROM dbo.PackHeader AS ph WITH (NOLOCK) WHERE ph.PickSlipNo = @c_PickSlipNo AND ph.[Status] = '9')
      BEGIN
         EXEC  isp_UnpackReversal  
               @c_PickSlipNo  = @c_PickSlipNo  
            ,  @c_UnpackType  = 'R'  
            ,  @b_Success     = @b_Success   OUTPUT   
            ,  @n_err         = @n_err       OUTPUT   
            ,  @c_errmsg      = @c_errmsg    OUTPUT  
      
         IF @b_Success = 0
         BEGIN
            SET @n_Continue = 3        
            GOTO EXIT_SP
         END
      END

      ;WITH delctn AS ( SELECT pd.PickSlipNo, pd.CartonNo, pd.LabelNo, pd.LabelLine 
                        FROM dbo.PackDetail AS pd WITH (NOLOCK)
                        WHERE pd.PickSlipNo = @c_PickSlipNo AND pd.LabelNo = @c_LabelNo 
                      )
      DELETE p FROM dbo.PackDetail AS p WITH (ROWLOCK)
      JOIN delctn AS d ON p.PickSlipNo = d.PickSlipNo AND p.CartonNo = d.CartonNo 
                       AND p.LabelNo = d.LabelNo AND p.LabelLine = d.LabelLine       

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         SET @c_Errmsg = ERROR_MESSAGE()        
         SET @n_err = 560201
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) + ': Delete Packdetail fail. (lsp_Pack_Unpack_Wrapper)'
                       + ' (' + @c_Errmsg + ')'
         GOTO EXIT_SP
      END

      --#LFWM3259 - START
      --IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail AS pd WITH (NOLOCK) WHERE pd.PickSlipNo = @c_PickSlipNo )
      --BEGIN
      --   DELETE FROM dbo.PackHeader WITH (ROWLOCK) WHERE PickSlipNo = @c_PickSlipNo
         
      --   IF @@ERROR <> 0
      --   BEGIN
      --      SET @n_Continue = 3
      --      SET @c_Errmsg = ERROR_MESSAGE()        
      --      SET @n_err = 560202
      --      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) + ': Delete Packheader fail. (lsp_Pack_Unpack_Wrapper)'
      --                    + ' (' + @c_Errmsg + ')'
      --      GOTO EXIT_SP
      --   END
      --END
      --#LFWM3259 - END
     
      IF EXISTS ( SELECT 1 FROM dbo.PackHeader AS ph WITH (NOLOCK) WHERE ph.PickSlipNo = @c_PickSlipNo AND ph.TTLCNTS > 0 AND ph.Status <'9' )
      BEGIN
         UPDATE dbo.PackHeader WITH (ROWLOCK) SET TTLCNTS = TTLCNTS - 1, ArchiveCop = CASE WHEN ArchiveCop = '9' THEN '9' ELSE NULL END  
         WHERE PickSlipNo = @c_PickSlipNo
         
         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @c_Errmsg = ERROR_MESSAGE()        
            SET @n_err = 560203
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) + ': Update Packheader fail. (lsp_Pack_Unpack_Wrapper)'
                          + ' (' + @c_Errmsg + ')'
            GOTO EXIT_SP
         END
      END
      
      IF @c_ErrMsg = ''
      BEGIN
         SET @c_Errmsg = 'Unpack Completed.'
      END
   END TRY
   
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE() + '. (lsp_Pack_Unpack_Wrapper)'
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_Pack_Unpack_Wrapper'
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