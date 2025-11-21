SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: lsp_WaveReleaseTask                                 */                                                                                  
/* Creation Date: 2019-03-19                                            */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-1646 Wave Creation - Wave Summary - Release Wave       */
/*                                                                      */                                                                                  
/* Called By: SCE                                                       */                                                                                  
/*          :                                                           */                                                                                  
/* PVCS Version: 1.3                                                    */                                                                                  
/*                                                                      */                                                                                  
/* Version: 8.0                                                         */                                                                                  
/*                                                                      */                                                                                  
/* Data Modifications:                                                  */                                                                                  
/*                                                                      */                                                                                  
/* Updates:                                                             */                                                                                  
/* Date        Author   Ver.  Purposes                                  */ 
/* 2021-02-10  mingle01 1.1   Add Big Outer Begin try/Catch              */
/*                            Execute Login if @c_UserName<>SUSER_SNAME()*/ 
/* 2021-09-28  Wan01    1.2   DevOps Combine Script.                     */
/* 2021-08-12  wan01    1.2   Fixed. 1) to rollback for xact_status      */
/*                            2) Start Transaction For Batch Commit      */
/* 2021-12-02  Wan02    1.3   LFWM-2997 - UAT CN - Outbound Ship Reference*/
/*                            for CSHP                                  */
/************************************************************************/                                                                                  
CREATE PROC [WM].[lsp_WaveReleaseTask]                                                                                                                     
      @c_WaveKey              NVARCHAR(10) = ''       --(Wan02) Call From MBOLScreen
   ,  @c_Loadkey              NVARCHAR(10) = ''
   ,  @c_MBolkey              NVARCHAR(10) = ''
   ,  @b_Success              INT = 1           OUTPUT  
   ,  @n_err                  INT = 0           OUTPUT                                                                                                             
   ,  @c_ErrMsg               NVARCHAR(255)     OUTPUT 
   ,  @n_WarningNo            INT          = 0  OUTPUT
   ,  @c_ProceedWithWarning   CHAR(1)      = 'N'                      
   ,  @c_UserName             NVARCHAR(128)= ''                                                                                                                         

AS  
BEGIN                                                                                                                                                        
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF       

   DECLARE  @n_StartTCnt      INT = @@TRANCOUNT  
         ,  @n_Continue       INT = 1

         ,  @n_OrderCnt       INT = 0
         ,  @c_PickDetailkey  NVARCHAR(10) = ''
         ,  @c_WaveStatus     NVARCHAR(10) = '0'

         ,  @CUR_WAVEPD       CURSOR 

   SET @b_Success = 1
   SET @n_Err     = 0
   
   BEGIN TRAN        --(Wan01)
                               
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
         SET @c_ErrMsg = 'Do you want to Release '
                       + CASE WHEN @c_Loadkey <> '' 
                              THEN ' Selected Load #'  
                              WHEN @c_MBOLkey <> '' 
                              THEN ' Selected MBOL #'  
                              ELSE ' Wave #: ' + @c_WaveKey
                              END
                       + ' task ?'
         GOTO EXIT_SP
      END

      IF @c_Loadkey <> '' AND @c_MBolkey <> '' AND @c_WaveKey <> ''        --(Wan02)
      BEGIN
         SET @n_continue = 3
         SET @n_err = 555801
         SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err)
                        + ': Disallow select both Load & Ship Ref. Unit to release task. (lsp_WaveReleaseTask)'
         GOTO EXIT_SP
      END

      SET @n_OrderCnt = 0
      IF @c_Loadkey = '' AND @c_MBolkey = ''
      BEGIN
         SELECT @n_OrderCnt = 1 
         FROM WAVEDETAIL WD WITH (NOLOCK)
         WHERE WD.WaveKey = @c_WaveKey 
      END 
      ELSE IF @c_Loadkey <> ''
      BEGIN 
         SELECT @n_OrderCnt = 1 
         FROM LOADPLANDETAIL LPD WITH (NOLOCK)
         WHERE LPD.LoadKey = @c_LoadKey 
      END
      ELSE IF @c_MBolkey <> ''
      BEGIN 
         --(Wan02) - START -- There is Sub Sub-Stored Prod / scenario to generate MBOLDETAIL FROM Container
         SET @n_OrderCnt = 1
         --SELECT @n_OrderCnt = 1 
         --FROM MBOLDETAIL MD WITH (NOLOCK)
         --WHERE MD.MBolKey = @c_MBolkey
         --(Wan02) - END 
      END

      IF @n_OrderCnt = 0
      BEGIN
         IF @c_Loadkey = '' AND @c_MBolkey = ''
         BEGIN
            SET @n_continue = 3
            SET @n_err = 555802
            SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err)
                           + ': No Orders to release task. (lsp_WaveReleaseTask)'
         END
         GOTO EXIT_SP
      END

      IF @c_Loadkey = '' AND @c_MBolkey = ''
      BEGIN
         WAVE_RELEASE:
         SET @CUR_WAVEPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PD.PickDetailkey 
         FROM WAVEDETAIL WD WITH (NOLOCK)
         JOIN PICKDETAIL PD WITH (NOLOCK) ON (WD.Orderkey = PD.Orderkey)
         WHERE WD.WaveKey = @c_WaveKey
         AND  PD.Wavekey  = ''
         AND  PD.[Status] = '0'
         ORDER BY WD.WaveDetailkey
               ,  PD.PickDetailkey

         OPEN @CUR_WAVEPD
      
         FETCH NEXT FROM @CUR_WAVEPD INTO @c_PickDetailkey                                                                                
                                       
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            BEGIN TRY
               UPDATE PICKDETAIL 
               SET Wavekey = @c_Wavekey
                  ,Trafficcop = NULL
                  ,EditWho = @c_UserName
                  ,EditDate= GETDATE()
               WHERE PickDetailKey = @c_PickDetailkey
               AND  Wavekey  = ''
               AND  [Status] = '0'
            END TRY

            BEGIN CATCH
               SET @n_Continue = 3
               SET @c_ErrMsg = ERROR_MESSAGE()
               SET @n_Err = 555803
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Update PICKDETAIL Fail. (lsp_WaveReleaseTask)'
                             + '(' + @c_ErrMsg + ')'

               IF (XACT_STATE()) = -1  
               BEGIN
                  ROLLBACK TRAN

                  WHILE @@TRANCOUNT < @n_StartTCnt
                  BEGIN
                     BEGIN TRAN
                  END
               END 
               GOTO EXIT_SP 
            END CATCH

            FETCH NEXT FROM @CUR_WAVEPD INTO @c_PickDetailkey       
         END
         CLOSE @CUR_WAVEPD
         DEALLOCATE @CUR_WAVEPD

         SET @c_WaveStatus = '0'
         SELECT @c_WaveStatus = WH.[Status]
         FROM WAVE WH WITH (NOLOCK)
         WHERE WH.Wavekey = @c_Wavekey

         BEGIN TRY
            EXEC  [dbo].[isp_ReleaseWave_Wrapper]  
                 @c_WaveKey = @c_WaveKey    
               , @b_Success = @b_Success OUTPUT
               , @n_Err     = @n_Err     OUTPUT 
               , @c_ErrMsg  = @c_ErrMsg  OUTPUT 
         END TRY
         BEGIN CATCH
            SET @n_Err = 555804
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Executing isp_ReleaseWave_Wrapper. (lsp_WaveReleaseTask)'   
                          + '(' + @c_ErrMsg + ')'
                            
            IF (XACT_STATE()) = -1        --(Wan01) - START 
            BEGIN
               ROLLBACK TRAN

               WHILE @@TRANCOUNT < @n_StartTCnt
               BEGIN
                  BEGIN TRAN
               END
            END                           --(Wan01) - END                                 
         END CATCH
            
         IF @b_Success = 0 OR @n_Err <> 0
         BEGIN
            SET @n_Continue = 3
            GOTO EXIT_SP   
         END

         BEGIN TRY
            UPDATE WAVE
               SET TMReleaseFlag = 'Y'
                  ,[Status] = @c_WaveStatus  -- REverse WAVE.Status update When calling isp_ReleaseWave_Wrapper
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
         LOAD_RELEASE:

         BEGIN TRY
            EXEC  [dbo].[nspLoadReleasePickTask_Wrapper]  
                 @c_LoadKey = @c_Loadkey    
         END TRY
         BEGIN CATCH
            SET @n_Err = 555805
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Executing nspLoadReleasePickTask_Wrapper. (lsp_WaveReleaseTask)'   
                          + '(' + @c_ErrMsg + ')'          
         END CATCH
            
         IF @b_Success = 0 OR @n_Err <> 0
         BEGIN
            SET @n_Continue = 3
            GOTO EXIT_SP   
         END
      END
      ELSE IF @c_MBolkey <> ''
      BEGIN
         MBOL_RELEASE:

         BEGIN TRY
            EXEC  [dbo].[isp_MBOLReleasePickTask_Wrapper]  
                 @c_MBolKey = @c_MBolKey    
               , @b_Success = @b_Success OUTPUT
               , @n_Err     = @n_Err     OUTPUT 
               , @c_ErrMsg  = @c_ErrMsg  OUTPUT 
         END TRY
         BEGIN CATCH
            SET @n_Err = 555806
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Executing isp_MBOLReleasePickTask_Wrapper. (lsp_WaveReleaseTask)'   
                          + '(' + @c_ErrMsg + ')'          
         END CATCH
            
         IF @b_Success = 0 OR @n_Err <> 0
         BEGIN
            SET @n_Continue = 3
            GOTO EXIT_SP   
         END
      END

      SET @c_ErrMsg = CASE WHEN @c_WaveKey = '' THEN 'Release Task Completed.' ELSE 'Wave Release Task Completed.' END        --(Wan02)
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_WaveReleaseTask'
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