SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: lsp_BuildWave_ClrBuildVal                           */                                                                                  
/* Creation Date: 08-MAR-2018                                           */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-1790 - SPs for Wave Release Screen - ( Wave Creation   */
/*          Tab - HomeScreen )                                          */                                                                                  
/*                                                                      */                                                                                  
/* Called By: SCE                                                       */                                                                                  
/*          :                                                           */                                                                                  
/* PVCS Version: 1.1                                                    */                                                                                  
/*                                                                      */                                                                                  
/* Version: 8.0                                                         */                                                                                  
/*                                                                      */                                                                                  
/* Data Modifications:                                                  */                                                                                  
/*                                                                      */                                                                                  
/* Updates:                                                             */                                                                                  
/* Date        Author   Ver.  Purposes                                  */  
/* 28-Dec-2020 SWT01    1.0   Adding Begin Try/Catch                    */
/* 15-Jan-2021 Wan01    1.1   Add Big Outer Begin try/Catch             */
/*                            Execute Login if @c_UserName<>SUSER_SNAME()*/
/************************************************************************/                                                                                  
CREATE PROC [WM].[lsp_BuildWave_ClrBuildVal]                                                                                                                       
      @c_BuildParmKey      NVARCHAR(10)                                                                                                                    
   ,  @b_Success           INT            = 1  OUTPUT  
   ,  @n_err               INT            = 0  OUTPUT                                                                                                             
   ,  @c_ErrMsg            NVARCHAR(255)  = '' OUTPUT 
   ,  @c_UserName          NVARCHAR(128)  = ''                  
AS
BEGIN
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF                                                                                                                          
   
   DECLARE @n_Continue        BIT = 1
         , @n_StartTCnt       INT = @@TRANCOUNT  
         
         , @c_BuildParmLineNo NVARCHAR(5) = ''                                                                                                                               
  
   DECLARE @CUR_BPD           CURSOR

   SET @b_Success = 1

   SET @n_Err = 0 
   
   IF SUSER_SNAME() <> @c_UserName        --(Wan01) 
   BEGIN 
      EXEC [WM].[lsp_SetUser] 
            @c_UserName = @c_UserName  OUTPUT
         ,  @n_Err      = @n_Err       OUTPUT
         ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT
                
      IF @n_Err <> 0 
      BEGIN
         GOTO EXIT_SP
      END  
                      
      EXECUTE AS LOGIN = @c_UserName      --(Wan01) 
   END
   
   BEGIN TRY   --(Wan01) - START
      BEGIN TRAN

      IF EXISTS ( SELECT 1 
                  FROM BUILDPARM WITH (NOLOCK)
                  WHERE BuildParmKey = @c_BuildParmKey
                  AND ( RestrictionBuildValue01 <> '' OR RestrictionBuildValue02 <> '' OR 
                        RestrictionBuildValue03 <> '' OR RestrictionBuildValue04 <> '' OR 
                        RestrictionBuildValue05 <> ''
                      )
                )
      BEGIN
         BEGIN TRY                                                                                                                                                      
            UPDATE BUILDPARM 
               SET   RestrictionBuildValue01 = ''
                  ,  RestrictionBuildValue02 = ''
                  ,  RestrictionBuildValue03 = ''
                  ,  RestrictionBuildValue04 = ''
                  ,  RestrictionBuildValue05 = ''
                  ,  EditDate = GETDATE()
                  ,  EditWho  = @c_UserName
                  ,  TrafficCop = NULL
            WHERE BuildParmKey = @c_BuildParmKey
         END TRY

         BEGIN CATCH
            SET @n_Continue = 3
            SET @n_Err     = 555551
            SET @c_ErrMsg  = ERROR_MESSAGE()                                                                                                                                                        
            SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err) 
                           + ': Update BUILDPARM fail. Actual Build Values Not Clear. (lsp_BuildWave_ClrBuildVal) '
                           + '( ' + @c_ErrMsg + ' )'    

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
      END

      SET @c_BuildParmLineNo = ''
      SET @CUR_BPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
      SELECT Code = BPD.BuildParmLineNo
      FROM BUILDPARMDETAIL BPD WITH (NOLOCK)
      WHERE BPD.BuildParmKey = @c_BuildParmKey
      AND   BPD.BuildValue <> ''
      ORDER BY BPD.BuildParmLineNo                                                                                                                                            
                                                                                                                                                            
      OPEN @CUR_BPD                                                                                                                                    
                                                                                                                                                            
      FETCH NEXT FROM @CUR_BPD INTO @c_BuildParmLineNo
                                                                    
      WHILE @@FETCH_STATUS <> -1                             
      BEGIN 
         BEGIN TRAN
         BEGIN TRY                                                                                                                                                      
            UPDATE BUILDPARMDETAIL
               SET   BuildValue = ''
                  ,  EditDate = GETDATE()
                  ,  EditWho  = @c_UserName
                  ,  TrafficCop = NULL
            WHERE BuildParmKey = @c_BuildParmKey
            AND   BuildParmLineNo = @c_BuildParmLineNo  
            AND   BuildValue <> ''
         END TRY

         BEGIN CATCH
            SET @n_Continue = 3
            SET @n_Err     = 555552
            SET @c_ErrMsg  = ERROR_MESSAGE()                                                                                                                                                        
            SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err) 
                           + ': Update BUILDPARMDETAIL fail. Actual Build Value Not Clear. (lsp_BuildWave_ClrBuildVal) '
                           + '( ' + @c_ErrMsg + ' )'    

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

         WHILE @@TRANCOUNT > 0 
         BEGIN
            COMMIT TRAN
         END

         FETCH NEXT FROM @CUR_BPD INTO @c_BuildParmLineNo
      END                                                                                                                                                            
      CLOSE @CUR_BPD
      DEALLOCATE @CUR_BPD
   END TRY
   BEGIN CATCH
      SET @n_Continue = 3   
      SET @c_ErrMsg   = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH            --(Wan01) - END
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_BuildWave_ClrBuildVal'
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
END -- Procedure

GO