SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                    
/* Store Procedure: lsp_Build_Wave_Post                                 */                                                                                    
/* Creation Date: 2023-05-17                                            */                                                                                    
/* Copyright: Maersk                                                    */                                                                                    
/* Written by: Wan                                                      */                                                                                    
/*                                                                      */                                                                                    
/* Purpose: LFWM-4244 - PROD - CN  SCE Wave BuildGenerate Load          */                                                                                    
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
/* 2023-05-17  Wan      1.0   Created & DevOps Combine Script           */  
/* 2023-08-17  Wan01    1.1   LFWM-4416 - UAT CN  Apply to both B2B and */
/*                            B2C for SCE Build Wave Auto Build Load    */
/************************************************************************/                                                                                    
CREATE   PROC [WM].[lsp_Build_Wave_Post]                                                                                                                         
   @n_BatchNo                 BIGINT 
,  @n_BuildWaveDetailLog_From BIGINT         = 0
,  @n_BuildWaveDetailLog_To   BIGINT         = 0
,  @b_Success                 INT            = 1  OUTPUT    
,  @n_err                     INT            = 0  OUTPUT                                                                                                               
,  @c_ErrMsg                  NVARCHAR(255)  = '' OUTPUT   
,  @b_debug                   INT            = 0                                                                                                                                
AS                                                                                                                                                                           
BEGIN  
   SET NOCOUNT ON                                                                                                                                             
   SET ANSI_NULLS OFF                                                                                                                               
   SET QUOTED_IDENTIFIER OFF                                                                                                                                  
   SET CONCAT_NULL_YIELDS_NULL OFF                                                                                                                            
     
   DECLARE @n_Continue                 INT            = 1  
         , @n_StartTCnt                INT            = @@TRANCOUNT  
           
         , @n_BackEndProcess           INT            = 0  
           
         , @c_Facility                 NVARCHAR(5)    = ''                                                                                                                   
         , @c_StorerKey                NVARCHAR(15)   = ''  
 
         , @c_Wavekey                  NVARCHAR(10)   = ''     
         , @c_UserName                 NVARCHAR(128)  = SUSER_SNAME()     
           
         , @c_ProcessType              NVARCHAR(10)   = 'BldWavLoad'              
         , @c_DocumentKey1             NVARCHAR(50)   = ''      
         , @c_SourceType               NVARCHAR(50)   = 'WM.lsp_WaveCreate'                                  
         , @c_CallType                 NVARCHAR(50)   = ''                            
         , @c_ExecCmd                  NVARCHAR(MAX)  = '' 
                                   
         , @c_SCEBuildWaveGenLoad      NVARCHAR(10)   = ''  
         , @c_SCEBuildWaveGenLoad_Op5  NVARCHAR(MAX)  = ''                          --(Wan01) 
         , @c_BuildWaveGenLoadParmKey  NVARCHAR(2000) = ''                         
         , @c_AddGenLoadParmKey        NVARCHAR(1000) = ''                          --(Wan01)
                   
         , @CUR_WAVE                   CURSOR 
         
   DECLARE @t_WaveGenLoad              TABLE                                        --(Wan01) - START  
         (  RowID                      INT   IDENTITY(1,1)  
         ,  BuildParmKey               NVARCHAR(50) NOT NULL DEFAULT('')  
         )                                                                          --(Wan01) - END    
           
   SET @b_Success = 1  
   SET @n_Err     = 0  
     
   BEGIN TRY  
      SELECT @c_Facility  = b.Facility  
            ,@c_Storerkey = b.Storerkey  
      FROM dbo.BUILDWAVELOG AS b WITH (NOLOCK)  
      WHERE b.BatchNo = @n_BatchNo  

      SELECT @c_SCEBuildWaveGenLoad  = fsgr.Authority
            ,@c_BuildWaveGenLoadParmKey = ISNULL(fsgr.ConfigOption1,'')
            ,@c_SCEBuildWaveGenLoad_Op5 = ISNULL(fsgr.ConfigOption5,'')                                        --(Wan01) - START
      FROM dbo.fnc_SelectGetRight(@c_Facility, @c_Storerkey, '', 'SCEBuildWaveGenLoad') AS fsgr 

      SET @c_AddGenLoadParmKey = ''
      SELECT @c_AddGenLoadParmKey = dbo.fnc_GetParamValueFromString('@c_AddGenLoadParmKey', @c_SCEBuildWaveGenLoad_Op5, @c_AddGenLoadParmKey)
       
      IF @c_AddGenLoadParmKey <> '' AND @c_BuildWaveGenLoadParmKey <> ''
      BEGIN
         SET @c_BuildWaveGenLoadParmKey = @c_BuildWaveGenLoadParmKey + ',' + @c_AddGenLoadParmKey
      END                                                                                                     --(Wan01) - END
              
      IF @c_SCEBuildWaveGenLoad IN ( '', '0' ) OR @c_BuildWaveGenLoadParmKey = ''  
      BEGIN  
         GOTO EXIT_SP   
      END  
        
      INSERT INTO @t_WaveGenLoad (BuildParmKey)
      SELECT ss.[value]
      FROM STRING_SPLIT(@c_BuildWaveGenLoadParmKey,',') AS ss 
      ORDER BY ss.[value]
      
      IF NOT EXISTS (SELECT 1   
                     FROM dbo.BUILDPARMGROUPCFG AS b WITH (NOLOCK)         
                     JOIN dbo.BUILDPARM AS b2 (NOLOCK) ON b2.ParmGroup = b.ParmGroup  
                     JOIN @t_WaveGenLoad AS twgl ON twgl.BuildParmKey = b2.BuildParmKey                        --(Wan01)
                     WHERE b.Facility = @c_Facility  
                     AND b.Storerkey = @c_Storerkey  
                     AND b.[Type] = 'WaveBuildLoad'  
                     --AND b2.BuildParmKey = @c_BuildWaveGenLoadParmKey                                        --(Wan01)
                     )  
      BEGIN   
         SET @n_Continue = 3  
         SET @n_err = 561651  
         SET @c_ErrMsg = 'NSQL'+ CONVERT(CHAR(6),@n_err) + ': WaveBuildLoad Parm Key: ' + @c_BuildWaveGenLoadParmKey  
                       + ' not found. No Loadplan generate at build Wave process. (lsp_Build_Wave_Post) |' + @c_BuildWaveGenLoadParmKey        
         GOTO EXIT_SP   
      END  
        
      SELECT @n_BackEndProcess = 1   
      FROM  dbo.QCmd_TransmitlogConfig qcfg WITH (NOLOCK)    
      WHERE qcfg.TableName      = 'BackEndProcessQueue'  
      AND   qcfg.[App_Name]     = 'WMS'    
      AND   qcfg.DataStream     = @c_ProcessType     
      AND   qcfg.StorerKey IN (@c_Storerkey, 'ALL')  
        
      BEGIN TRAN  
      SET @CUR_WAVE = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT b.Wavekey  
      FROM dbo.BUILDWAVEDETAILLOG AS b WITH (NOLOCK)  
      WHERE b.BatchNo = @n_BatchNo 
      AND b.RowRef BETWEEN @n_BuildWaveDetailLog_From AND @n_BuildWaveDetailLog_To 
      AND EXISTS (SELECT 1  
                  FROM dbo.WAVEDETAIL AS w WITH (NOLOCK)   
                  JOIN dbo.ORDERS AS o WITH (NOLOCK) ON o.OrderKey = w.OrderKey  
                  WHERE w.Wavekey = b.Wavekey  
                  AND o.LoadKey IN ('', NULL))  
      ORDER BY b.RowRef  
        
      OPEN @CUR_WAVE  
        
      FETCH NEXT FROM @CUR_WAVE INTO @c_Wavekey  
           
      WHILE @@FETCH_STATUS <> - 1 AND @n_Continue = 1  
      BEGIN  
         SET @c_BuildWaveGenLoadParmKey= ''
         WHILE 1 = 1                                                                                           --(Wan01) - START 
         BEGIN  
            SELECT TOP 1 @c_BuildWaveGenLoadParmKey = twgl.BuildParmKey  
            FROM @t_WaveGenLoad AS twgl  
            WHERE twgl.BuildParmKey > @c_BuildWaveGenLoadParmKey  
            ORDER BY twgl.BuildParmKey   
        
            IF @@ROWCOUNT = 0   
            BEGIN  
               BREAK  
            END  
            
            IF @n_BackEndProcess = 1   
            BEGIN   
               SET @c_CallType= 'WM.lsp_Build_Wave_Post'  
               SET @c_ExecCmd = 'WM.lsp_Wave_BuildLoad'  
                              + ' @c_Wavekey  = ''' + @c_Wavekey  + ''''  
                              + ',@c_Facility = ''' + @c_Facility + ''''                                                                                                                    
                              + ',@c_StorerKey= ''' + @c_StorerKey+ ''''        
                              + ',@b_Success = @b_Success OUTPUT'  
                              + ',@n_Err = @n_Err OUTPUT'  
                              + ',@c_ErrMsg = @c_Errmsg OUTPUT'  
                              + ',@c_UserName = ''' + @c_UserName + ''''  
                              + ',@b_debug = 0'    
                              + ',@c_WaveBuildLoadParmkey  = ''' + @c_BuildWaveGenLoadParmKey + ''''  
           
               SET @c_DocumentKey1 = @c_WaveKey  
   
               EXEC [WM].[lsp_BackEndProcess_Submit]                                                                                                                       
                  @c_Storerkey      = @c_Storerkey  
               ,  @c_ModuleID       = 'Wave'   
               ,  @c_DocumentKey1   = @c_DocumentKey1    
               ,  @c_DocumentKey2   = ''        
               ,  @c_DocumentKey3   = ''        
               ,  @c_ProcessType    = @c_ProcessType     
               ,  @c_SourceType     = @c_SourceType      
               ,  @c_CallType       = @c_CallType  
               ,  @c_RefKey1        = ''        
               ,  @c_RefKey2        = ''        
               ,  @c_RefKey3        = ''     
               ,  @c_ExecCmd        = @c_ExecCmd    
               ,  @c_StatusMsg      = 'Submitted to BackEndProcessQueue.'  
               ,  @b_Success        = @b_Success   OUTPUT    
               ,  @n_err            = @n_err       OUTPUT                                                                                                               
               ,  @c_ErrMsg         = @c_ErrMsg    OUTPUT    
               ,  @c_UserName       = ''   
           
               IF @b_Success = 0   
               BEGIN  
                  SET @n_Continue = 3  
                  SET @n_err = 561652  
                  SET @c_ErrMsg = 'NSQL'+ CONVERT(Char(6),@n_err) + ': Error Executing WM.lsp_BackEndProcess_Submit'  
                        + '. (lsp_Build_Wave_Post) ( ' + @c_ErrMsg + ' )'  
               END  
            END  
            ELSE  
            BEGIN  
               EXEC [WM].[lsp_Wave_BuildLoad]                                                                                                                         
                     @c_Wavekey              = @c_Wavekey           
                  ,  @c_Facility             = @c_Facility                                                                                                                      
                  ,  @c_StorerKey            = @c_StorerKey         
                  ,  @b_Success              = @b_Success         OUTPUT    
                  ,  @n_err                  = @n_err             OUTPUT                                                                                                               
                  ,  @c_ErrMsg               = @c_ErrMsg          OUTPUT   
                  ,  @c_UserName             = @c_UserName                        
                  ,  @b_debug                = @b_debug      
                  ,  @c_WaveBuildLoadParmkey = @c_BuildWaveGenLoadParmKey                    
            END  
         END                                                                                                   --(Wan01) - END      
         FETCH NEXT FROM @CUR_WAVE INTO @c_Wavekey              
      END    
   END TRY  
   BEGIN CATCH  
      SET @n_Continue = 3  
      SET @c_ErrMsg = ERROR_MESSAGE()  
      GOTO EXIT_SP  
   END CATCH  
     
   EXIT_SP:  
   IF @n_Continue = 3  
   BEGIN  
      IF @n_StartTCnt = 1 AND @@TRANCOUNT >= @n_StartTCnt   
      BEGIN  
         ROLLBACK TRAN  
      END  
      SET @b_Success = 0  
   END  
   ELSE  
   BEGIN   
      WHILE @@TRANCOUNT > @n_StartTCnt   
      BEGIN  
         COMMIT TRAN  
      END  
      SET @b_Success = 1  
   END  
     
   WHILE @@TRANCOUNT < @n_StartTCnt  
   BEGIN  
      BEGIN TRAN   
   END  
END  

GO