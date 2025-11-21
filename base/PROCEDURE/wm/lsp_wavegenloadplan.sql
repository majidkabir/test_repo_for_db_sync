SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: lsp_WaveGenLoadPlan                                 */                                                                                  
/* Creation Date: 2019-03-19                                            */                                                                                  
/* Copyright: Maersk                                                    */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-1651 -  Wave Summary - Wave Control - Generate Loadplan*/
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
/* 2021-02-24  Wan01    1.1   Fixed Pass into Sub SP to check if to execute*/
/*                            login if @c_UserName <> SUSER_SNAME()     */ 
/* 2022-02-25  Wan02    1.2   Fix Blocking & Add Begin Tran             */
/* 2023-06-23  Wan03    1.3   LFWM-4176 - CN UAT  Split wave into loads */
/*                            based on customized SP                    */
/*                            DevOps Combine Script                     */
/************************************************************************/                                                                                  
CREATE   PROC [WM].[lsp_WaveGenLoadPlan]                                                                                                                     
      @c_WaveKey           NVARCHAR(10)
   ,  @b_Success           INT = 1           OUTPUT  
   ,  @n_err               INT = 0           OUTPUT                                                                                                             
   ,  @c_ErrMsg            NVARCHAR(255)= '' OUTPUT               
   ,  @c_UserName          NVARCHAR(128)= '' 
   ,  @b_PopupWindow       INT = 0           OUTPUT                                 --(Wan03)
   ,  @n_NoOfOrderNoLoad   INT = 0           OUTPUT                                 --(Wan03)   
   ,  @c_BuildParmKeys     NVARCHAR(2000)='' --Selected Buildparmkey seperator by | --(Wan03)
AS  
BEGIN                                                                                                                                                        
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF       

   DECLARE  @n_StartTCnt               INT = @@TRANCOUNT  
         ,  @n_Continue                INT = 1
         ,  @b_debug                   INT = 0                                      --(Wan03)
         
         ,  @n_ParmGroupCfgID          INT = 0                                      --(Wan03)
         ,  @n_BuildParmkey            INT = 0                                      --(Wan03) 
         ,  @n_RowID                   INT = 0                                      --(Wan03)
         ,  @b_WaveGenLoadFlag_Upd     INT = 0                                      --(Wan03)
    
         ,  @c_Facility                NVARCHAR(5)  = ''
         ,  @c_Storerkey               NVARCHAR(15) = ''

         ,  @c_SchemaSP                NVARCHAR(10) = ''
         ,  @c_SQL                     NVARCHAR(1000)= ''
         ,  @c_SQLParms                NVARCHAR(1000)=''

         ,  @c_WaveGenLoadPlanSP       NVARCHAR(30) = ''
         ,  @c_BuildParmKey            NVARCHAR(50) = ''
         
    DECLARE @t_WaveGenLoad             TABLE                                       --(Wan03) - START
         (  RowID                      INT   IDENTITY(1,1)
         ,  BuildParmKey               NVARCHAR(50) NOT NULL DEFAULT('')
         )                                                                          --(Wan03) - END    
         
   SET @b_Success = 1
   SET @n_Err     = 0
               
   SET @n_Err = 0 
   EXEC [WM].[lsp_SetUser] 
         @c_UserName = @c_UserName  OUTPUT
      ,  @n_Err      = @n_Err       OUTPUT
      ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT
                
   EXECUTE AS LOGIN = @c_UserName

   IF @n_Err <> 0 
   BEGIN
      GOTO EXIT_SP
   END 

   IF NOT EXISTS( SELECT 1 FROM WAVEDETAIL WITH (NOLOCK)
                  WHERE WaveKey = @c_WaveKey )
   BEGIN
      SET @n_continue = 3
      SET @n_err = 555651
      SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err)
                    + ': No Orders populates to Wave. (lsp_WaveGenLoadPlan)'
      GOTO EXIT_SP
   END

   SET @c_Storerkey= ''
   SET @c_Facility = ''
   SELECT TOP 1 @c_Storerkey = OH.Storerkey
         , @c_Facility = OH.Facility
   FROM WAVEDETAIL WD WITH (NOLOCK)
   JOIN ORDERS OH WITH (NOLOCK) ON (WD.Orderkey = OH.Orderkey)
   WHERE WD.Wavekey = @c_WaveKey    
   ORDER BY WD.WaveDetailKey  

   BEGIN TRAN
   IF @c_BuildParmKeys = '' AND @b_PopupWindow = 0                                  --(Wan03)
   BEGIN
      BEGIN TRY
         EXEC nspGetRight
               @c_Facility   = @c_Facility         
             , @c_StorerKey  = @c_StorerKey        
             , @c_sku        = ''     
             , @c_ConfigKey  = 'WaveGenLoadPlan'       
             , @c_authority  = @c_WaveGenLoadPlanSP      OUTPUT
             , @b_Success    = @b_Success                OUTPUT
             , @n_err        = @n_err                    OUTPUT
             , @c_errmsg     = @c_errmsg                 OUTPUT
      
         --(Wan02) - START    
         IF @b_Success = 0
         BEGIN
            SET @n_Continue = 3
            SET @c_ErrMsg = @c_ErrMsg + '. (lsp_WaveGenLoadPlan)' 
            GOTO EXIT_SP  
         END
 
         --(Wan02) - END
      END TRY
      BEGIN CATCH
            SET @n_Continue = 3
            SET @n_Err = 555652
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Executing nspGetRight - WaveGenLoadPlan. (lsp_WaveGenLoadPlan)' 
                           + '(' + @c_ErrMsg + ')' 
            GOTO EXIT_SP                         
      END CATCH
   END                                                                              --(Wan03)

   IF @c_WaveGenLoadPlanSP NOT IN ('0','') OR @b_PopupWindow = 1                    --(Wan03) - START
   BEGIN
      IF EXISTS ( SELECT 1
                  FROM dbo.WAVE AS w  (NOLOCK)
                  WHERE w.Wavekey = @c_WaveKey
                  AND   w.WaveGenLoadFlag = 'Y'
                )
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 555655
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Wave is generating Loadpan in Progress. Abort.'
                       + ' (lsp_WaveGenLoadPlan)'
         GOTO EXIT_SP
      END
      
      UPDATE dbo.WAVE WITH (ROWLOCK)
      SET WaveGenLoadFlag = 'Y'
      WHERE Wavekey = @c_Wavekey
      AND   WaveGenLoadFlag = 'N'
      
      IF @@ROWCOUNT > 0 
      BEGIN
         SET @b_WaveGenLoadFlag_Upd = 1
      END
   END

   SET @c_BuildParmKey = ''
   IF @c_WaveGenLoadPlanSP IN ('0','')  
   BEGIN 
      BEGIN TRY                                                                       
         IF @c_BuildParmKeys = ''                                                      
         BEGIN
            INSERT INTO @t_WaveGenLoad
                (
                    BuildParmKey
                )
            SELECT 
                  BP.BuildParmKey
            FROM BUILDPARM BP WITH (NOLOCK)   
            JOIN BUILDPARMGROUPCFG BPCFG WITH (NOLOCK) ON BP.ParmGroup = BPCFG.ParmGroup
                                                      AND BPCFG.[Type] = 'WaveBuildLoad'
            WHERE BPCFG.Facility = @c_Facility
            AND   BPCFG.Storerkey= @c_Storerkey
            AND   bp.Active = '1' 
            ORDER BY BP.BuildParmKey
         END                                                                           
         ELSE
         BEGIN
            INSERT INTO @t_WaveGenLoad
               (
                  BuildParmKey
               )
            SELECT b.BuildParmKey   
            FROM STRING_SPLIT(@c_BuildParmKeys, '|') AS ss
            JOIN BUILDPARM AS b WITH (NOLOCK) ON b.BuildParmKey = ss.[value] 
            WHERE b.Active = '1'   
            ORDER BY b.Priority   
         END   
         SET @n_BuildParmkey = @@ROWCOUNT                                           --(Wan03) - END                               
      
         IF (@n_BuildParmkey > 0 AND @b_PopupWindow = 1) OR @n_BuildParmkey = 1     --(Wan03) - START
         BEGIN
            -- Standard SCE Wave Build Load
            SET @n_RowID = 0
            WHILE 1 = 1
            BEGIN
               SELECT TOP 1
                      @n_RowID = twgl.RowID
                     ,@c_BuildParmKey = twgl.BuildParmKey
               FROM @t_WaveGenLoad AS twgl
               WHERE twgl.RowID > @n_RowID
               ORDER BY twgl.RowID 
      
               IF @@ROWCOUNT = 0 
               BEGIN
                  BREAK
               END
      
               EXEC [WM].[lsp_Wave_BuildLoad]  
                    @c_WaveKey   = @c_WaveKey
                  , @c_Facility  = @c_Facility                                                                                                                            
                  , @c_StorerKey = @c_StorerKey           
                  , @b_Success   = @b_Success OUTPUT
                  , @n_Err       = @n_Err     OUTPUT 
                  , @c_ErrMsg    = @c_ErrMsg  OUTPUT
                  , @c_UserName  = @c_UserName                                      --(Wan01)
                  , @c_WaveBuildLoadParmkey = @c_BuildParmKey                       --(Wan03)  
                  , @b_debug     = @b_debug                                         --(Wan03)
    
               IF @b_Success = 0 OR @n_Err <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @n_Err = 555653
                  SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Executing WM.lsp_Wave_BuildLoad. (lsp_WaveGenLoadPlan)' 
                                 + '(' + @c_ErrMsg + ')'   
               END
            END   
         END   
      END TRY    
      BEGIN CATCH 
         SET @c_ErrMsg = ERROR_MESSAGE()
         IF (XACT_STATE()) = -1  
         BEGIN
            ROLLBACK TRAN  
         END
      END CATCH 
   
      IF @b_PopupWindow = 0 AND @n_BuildParmkey > 1
      BEGIN
         SET @b_PopupWindow = 1
      END 
       
      SELECT @n_NoOfOrderNoLoad = COUNT(1) 
      FROM dbo.ORDERS AS o (NOLOCK)
      JOIN WAVEDETAIL AS w (NOLOCK) ON w.OrderKey = o.OrderKey
      LEFT OUTER JOIN dbo.LoadPlanDetail AS lpd (NOLOCK) ON lpd.OrderKey = o.OrderKey
      WHERE w.WaveKey = @c_WaveKey
      AND lpd.LoadKey IS NULL
   END   

   IF @b_PopupWindow = 1 OR @n_BuildParmkey = 1
   BEGIN
      GOTO EXIT_SP                                                                  
   END                                                                              --(Wan03) - END 
                                                                                                   
   BEGIN TRY
      EXEC  [dbo].[isp_WaveGenLoadPlan_Wrapper]  
           @c_WaveKey = @c_WaveKey    
         , @b_Success = @b_Success OUTPUT
         , @n_Err     = @n_Err     OUTPUT 
         , @c_ErrMsg  = @c_ErrMsg  OUTPUT 
   END TRY
   BEGIN CATCH
      SET @n_Err = 555654
      SET @c_ErrMsg = ERROR_MESSAGE()
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Executing isp_WaveGenLoadPlan_Wrapper. (lsp_WaveGenLoadPlan)'   
                    + '(' + @c_ErrMsg + ')'          
   END CATCH
         
   IF @b_Success = 0 OR @n_Err <> 0
   BEGIN
      SET @n_Continue = 3
      GOTO EXIT_SP   
   END

EXIT_SP:
   --(Wan02) - START
   IF (XACT_STATE()) = -1  
   BEGIN
      ROLLBACK TRAN  
   END
   --(Wan02) - END
   
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @n_StartTCnt = 0 AND @@TRANCOUNT > @n_StartTCnt               --(Wan02)
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_WaveGenLoadPlan'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
   
   IF @b_WaveGenLoadFlag_Upd = 1                                                    --(Wan03) - START 
   BEGIN
      IF EXISTS ( SELECT 1                                                                    
                  FROM dbo.WAVE AS w  (NOLOCK)
                  WHERE w.Wavekey = @c_WaveKey
                  AND   w.WaveGenLoadFlag = 'Y'
                )
      BEGIN
         WHILE @@TRANCOUNT > 0
         BEGIN
            COMMIT TRAN
         END

         UPDATE dbo.WAVE WITH (ROWLOCK)
         SET WaveGenLoadFlag = 'N'
         WHERE Wavekey = @c_Wavekey
         AND   WaveGenLoadFlag = 'Y'
      END                                                                               
   END                                                                              --(Wan03) - END

   --(Wan02) - START 
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END 
   --(Wan02) - END  
   REVERT
END

GO