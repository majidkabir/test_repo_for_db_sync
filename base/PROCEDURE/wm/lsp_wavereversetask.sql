SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: lsp_WaveReverseTask                                 */                                                                                  
/* Creation Date: 2019-03-19                                            */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-1794 - SPs for Wave Control Screens                    */
/*          - ( Reverse Generated Task )                                */
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
/* 2021-09-28  Wan01    1.2   DevOps Combine Script.                    */
/* 2021-08-12  wan01    1.2   Start Transaction For Batch Commit        */
/************************************************************************/                                                                                  
CREATE PROC [WM].[lsp_WaveReverseTask]                                                                                                                     
      @c_WaveKey              NVARCHAR(10)
   ,  @c_Loadkey              NVARCHAR(10) = ''
   ,  @c_MBolkey              NVARCHAR(10) = ''
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

   DECLARE  @n_StartTCnt      INT = @@TRANCOUNT  
         ,  @n_Continue       INT = 1

   SET @b_Success = 1
   SET @n_Err     = 0
    
   BEGIN TRAN     --(Wan01)            
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

      SET @c_Loadkey = ISNULL(@c_Loadkey, '')
      SET @c_MBolkey = ISNULL(@c_MBolkey, '')
      IF @c_ProceedWithWarning = 'N' AND @n_WarningNo < 1
      BEGIN
         SET @n_WarningNo = 1
         SET @c_ErrMsg = 'Confirm to Reverse ' 
                       + CASE WHEN @c_Loadkey <> '' 
                              THEN ' Selected Load #' 
                              ELSE ' Wave #: ' + @c_WaveKey
                              END
                       + ' task ?'
         GOTO EXIT_SP
      END

      IF @c_MBolkey <> ''
      BEGIN
         SET @n_continue = 3
         SET @n_err = 555851
         SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err)
                        + ': Reverse task from MBOL is Not Available. (lsp_WaveReleaseTask)'
         GOTO EXIT_SP
      END

      IF @c_Loadkey = '' AND @c_MBolkey = ''
      BEGIN
         WAVE_REVERSE:
         BEGIN TRY
            EXEC  [dbo].[isp_ReverseWaveReleased_Wrapper]  
                 @c_WaveKey = @c_WaveKey    
               , @b_Success = @b_Success OUTPUT
               , @n_Err     = @n_Err     OUTPUT 
               , @c_ErrMsg  = @c_ErrMsg  OUTPUT 
         END TRY
         BEGIN CATCH
            SET @n_Err = 555852
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Executing isp_ReverseWaveReleased_Wrapper. (lsp_WaveReverseTask)'   
                          + '(' + @c_ErrMsg + ')'          
         END CATCH
            
         IF @b_Success = 0 OR @n_Err <> 0
         BEGIN
            SET @n_Continue = 3
            GOTO EXIT_SP   
         END

         BEGIN TRY
            UPDATE WAVE
               SET TMReleaseFlag = 'N'
                  ,TrafficCop = NULL
            WHERE WaveKey = @c_WaveKey
         END TRY

         BEGIN CATCH
            SET @n_Err = 555807
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Update WAVE table fail. (lsp_WaveReleaseTask)'   
                          + '(' + @c_ErrMsg + ')'  
            IF (XACT_STATE()) = -1  
            BEGIN
               ROLLBACK TRAN

               WHILE @@TRANCOUNT < @n_StartTCnt
               BEGIN
                  BEGIN TRAN
               END
            END 
         END CATCH
            
         IF @n_Err <> 0
         BEGIN
            SET @n_Continue = 3
            GOTO EXIT_SP   
         END
      END
      ELSE IF @c_Loadkey <> ''
      BEGIN 
         LOAD_REVERSE:

         BEGIN TRY
            EXEC  [dbo].[ispLoadReversePickTask_Wrapper]  
                 @c_LoadKey = @c_Loadkey 
               , @b_Success = @b_Success OUTPUT
               , @n_Err     = @n_Err     OUTPUT 
               , @c_ErrMsg  = @c_ErrMsg  OUTPUT                  
         END TRY
         BEGIN CATCH
            SET @n_Err = 555853
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Executing ispLoadReversePickTask_Wrapper. (lsp_WaveReverseTask)'   
                          + '(' + @c_ErrMsg + ')'          
         END CATCH
            
         IF @b_Success = 0 OR @n_Err <> 0
         BEGIN
            SET @n_Continue = 3
            GOTO EXIT_SP   
         END
      END
      SET @c_ErrMsg = 'Wave Reverse task Completed.'
   END TRY
   
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
   --(mingle01) - END
EXIT_SP:
   IF (XACT_STATE()) = -1                                      --(Wan01)  
   BEGIN
      SET @n_Continue = 3
      ROLLBACK TRAN
   END 
   
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF @n_StartTCnt = 0 AND @@TRANCOUNT > @n_StartTCnt       --(Wan01)
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_WaveReverseTask'
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