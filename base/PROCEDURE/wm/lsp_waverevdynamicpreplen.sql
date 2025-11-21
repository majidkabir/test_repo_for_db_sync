SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: lsp_WaveRevDynamicPReplen                           */                                                                                  
/* Creation Date: 2019-04-05                                            */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-1794 - SPs for Wave Control Screens                    */
/*          - ( Reverse DynamicP Replenishment Task)                    */
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
/* 2021-02-10  mingle01 1.1   Add Big Outer Begin try/Catch              */
/*                            Execute Login if @c_UserName<>SUSER_SNAME()*/ 
/************************************************************************/                                                                                  
CREATE PROC [WM].[lsp_WaveRevDynamicPReplen]                                                                                                                     
      @c_WaveKey              NVARCHAR(10)
   ,  @b_Success              INT = 1           OUTPUT  
   ,  @n_err                  INT = 0           OUTPUT                                                                                                             
   ,  @c_ErrMsg               NVARCHAR(255)     OUTPUT   
   ,  @n_WarningNo            INT          = 0  OUTPUT
   ,  @c_ProceedWithWarning   CHAR(1)      = 'N'                
   ,  @c_UserName             NVARCHAR(50) = ''                                                                                                                         

AS  
BEGIN                                                                                                                                                        
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF       

   DECLARE  @n_StartTCnt                  INT = @@TRANCOUNT  
         ,  @n_Continue                   INT = 1

   SET @b_Success = 1
   SET @n_Err     = 0
               
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

      IF @c_ProceedWithWarning = 'N' AND @n_WarningNo < 1
      BEGIN
         SET @n_WarningNo = 1
         SET @c_ErrMsg = 'Do you want to reverse Dynamic Pick Replenishment By Wave?'   
         GOTO EXIT_SP  
      END

      BEGIN TRY
         SET @n_Err = 0
         EXEC [dbo].[ispReverseDynamicLocReplenishment]  
              @cWaveKey    = @c_WaveKey 
            , @bSuccess    = @b_Success      OUTPUT
            , @nErrNo      = @n_Err          OUTPUT 
            , @cErrMsg     = @c_ErrMsg       OUTPUT 
      END TRY
      BEGIN CATCH
         SET @n_Continue = 3
         SET @n_Err = 556351
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Executing ispReverseDynamicLocReplenishment. (lsp_WaveRevDynamicPReplen)'   
                        + '(' + @c_ErrMsg + ')'  
                         
      END CATCH
            
      IF @b_Success = 0 OR @n_Continue = 3
      BEGIN
         GOTO EXIT_SP   
      END

      SET @c_ErrMsg = 'Reverse Dynamic Pick Replenishment Process is done.'
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
      SET @n_WarningNo = 0
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_WaveRevDynamicPReplen'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
   
   IF @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN 
   END
         
   REVERT
END

GO