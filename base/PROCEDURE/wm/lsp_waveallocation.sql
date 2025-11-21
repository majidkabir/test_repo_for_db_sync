SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: lsp_WaveAllocation                                  */                                                                                  
/* Creation Date: 2019-03-20                                            */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-1645 Wave Creation - Wave Summary - Allocate Wave      */
/*                                                                      */                                                                                  
/* Called By: SCE                                                       */                                                                                  
/*          :                                                           */                                                                                  
/* PVCS Version: 1.7                                                    */                                                                                  
/*                                                                      */                                                                                  
/* Version: 8.0                                                         */                                                                                  
/*                                                                      */                                                                                  
/* Data Modifications:                                                  */                                                                                  
/*                                                                      */                                                                                  
/* Updates:                                                             */                                                                                  
/* Date        Author   Ver.  Purposes                                  */  
/* 2021-02-10  mingle01 1.1   Add Big Outer Begin try/Catch             */
/*                            Execute Login if @c_UserName<>SUSER_SNAME()*/
/* 2021-05-05  Wan01    1.2   LFWM-2723 - RGMigrate Allocation schedule */
/*                            job to QCommander                         */
/* 2021-05-21  Wan02    1.3   LFWM-2803 - UATCN Allocate error          */
/* 2021-07-01  Wan03    1.4   LFWM-2808 - CN Allocate Enhancement       */
/* 2022-02-10  Wan04    1.5   Add Submit Qcommander By Priority         */
/* 2022-02-10  Wan04    1.5   DevOps Combine Script                     */
/* 2022-02-18  Wan05    1.6   LFWM-3334 -CN NIKECN Wave control QCmdUser*/
/* 2022-02-18  Wan06    1.6   LFWM-3280 - UAT|CN|SCE|Unable to allocate */
/*                            with stuck on 'submitted'                 */
/* 2022-12-16  Wan07    1.7   LFWM-3892 - [CN] UAT Converse-Wave Control*/
/*                            - Allocation issue                        */
/* 2023-04-11  Wan08    1.8   LFWM-4179 - PROD CN  Wave Control Allocate*/
/*                            single thread only support by storerkey,  */
/*                            not able to split by facility             */
/* 2024-01-15  NJOW01   1.9   WMS-24623 Fix SCE wave allocation custom  */
/*                            mode follow exceed                        */
/************************************************************************/                                                                                  
CREATE   PROC [WM].[lsp_WaveAllocation]                                                                                                                     
      @c_WaveKey              NVARCHAR(10)
   ,  @c_Loadkey              NVARCHAR(10) = ''
   ,  @c_AllocateType         NVARCHAR(15) = ''
   ,  @c_allocatemode         NVARCHAR(10) = '' OUTPUT
   ,  @b_Success              INT = 1           OUTPUT  
   ,  @n_err                  INT = 0           OUTPUT                                                                                                             
   ,  @c_ErrMsg               NVARCHAR(255)     OUTPUT   
   ,  @c_UserName             NVARCHAR(128)= '' 
   ,  @n_ErrGroupKey          INT          = 0  OUTPUT   -- Capture Warnings/Questions/Errors/Meassage into WMS_ERROR_LIST Table
AS  
BEGIN                                                                                                                                                        
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF       

   DECLARE  @n_StartTCnt                  INT = @@TRANCOUNT  
         ,  @n_Continue                   INT = 1
         ,  @n_Cnt                        INT = 0
            
         ,  @n_SortLoad                   INT = 0

         ,  @c_Facility                   NVARCHAR(5)  = ''
         ,  @c_Storerkey                  NVARCHAR(15) = ''
         ,  @c_Orderkey                   NVARCHAR(10) = ''
         ,  @c_ReflineNo                  NVARCHAR(10) = ''
         ,  @c_StrategykeyParm            NVARCHAR(10) = '' --(Wan03)

         ,  @c_FinalizeFlag               NVARCHAR(10) = ''
         ,  @c_SuperOrderFlag             NVARCHAR(10) = ''
         ,  @c_Source                     NVARCHAR(10) = ''

         ,  @c_FinalizeLP                 NVARCHAR(10) = ''

         ,  @c_WaveConsoAllocation        NVARCHAR(10) = ''
         ,  @c_LoadConsoAllocation        NVARCHAR(10) = ''
         ,  @c_ContinueAllocUnLoadSO      NVARCHAR(10) = ''
         ,  @c_ValidateCancelDate         NVARCHAR(10) = ''
         ,  @c_AllowLPAlloc4DiscreteOrd   NVARCHAR(10) = ''
         ,  @c_AllocateValidationRules    NVARCHAR(30) = ''

         ,  @c_SPName                     NVARCHAR(30) = ''
         ,  @c_SQL                        NVARCHAR(1000)=''
         ,  @c_SQLParms                   NVARCHAR(500) =''
         ,  @c_ExecCmd                    NVARCHAR(1024)= ''

         ,  @c_ValidateOrderkey           NVARCHAR(10) =''
         ,  @c_ValidateLoadkey            NVARCHAR(10) =''
         ,  @c_ValidateWavekey            NVARCHAR(10) =''
         ,  @c_SQLVLD                     NVARCHAR(1000)=''
         ,  @c_SQLVLDParms                NVARCHAR(500) =''

         ,  @c_DynamicPickLocStart        NVARCHAR(20)  =''

         ,  @c_TableName                  NVARCHAR(50)   = 'WAVE'
         ,  @c_SourceType                 NVARCHAR(50)   = 'lsp_WaveAllocation'
         
         ,  @n_ThreadPerAcct              INT            = 0   --(Wan01)    
         ,  @n_ThreadPerStream            INT            = 0   --(Wan01)
         ,  @n_MilisecondDelay            INT            = 0   --(Wan01)
         ,  @c_IP                         NVARCHAR(20)   = ''  --(Wan01)
         ,  @c_PORT                       NVARCHAR(5)    = ''  --(Wan01)
         ,  @c_IniFilePath                NVARCHAR(200)  = ''  --(Wan01)
         ,  @c_APP_DB_Name                NVARCHAR(20)   = ''  --(Wan01)
         ,  @c_DataStream                 NVARCHAR(10)   = ''  --(Wan01) 
         ,  @c_CmdType                    NVARCHAR(10)   = ''  --(Wan01)
         ,  @c_TaskType                   NVARCHAR(1)    = ''  --(Wan01)
         ,  @c_TransmitLogKey             NVARCHAR(10)   = ''  --(Wan01)
         ,  @n_Priority                   INT            = 0   --(Wan04)
         
         ,  @c_WaveType                   NVARCHAR(18)   = ''  --(Wan07)
         ,  @c_WaveAllowSelectStrategy    NVARCHAR(30)   = ''  --(Wan07)
         ,  @c_WaveGetStrategyByType      NVARCHAR(30)   = ''  --(Wan07)         

         ,  @CUR_WAVELOAD                 CURSOR
         ,  @CUR_ORD                      CURSOR

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
      IF @n_ErrGroupKey IS NULL
      BEGIN
         SET @n_ErrGroupKey = 0
      END

      SET @c_AllocateType = ISNULL(@c_AllocateType,'')
      SET @c_Loadkey = ISNULL(@c_Loadkey,'')

      IF @c_AllocateType = ''
      BEGIN
         IF @c_Loadkey = '' 
         BEGIN 
            SET @c_AllocateType = 'WAVE'
         END

         IF @c_Loadkey <> ''
         BEGIN 
            SET @c_AllocateType = 'LOAD'
            SET @c_TableName    = 'LOADPLAN'
         END
      END

      IF @c_AllocateType IN ( 'WAVE', 'UCC', 'DYNAMICPICK') 
      BEGIN
         SELECT TOP 1 
                 @c_Facility = OH.Facility
               , @c_Storerkey= OH.Storerkey
         FROM WAVEDETAIL WD WITH (NOLOCK)
         JOIN ORDERS OH WITH (NOLOCK) ON WD.Orderkey = OH.Orderkey
         WHERE WD.Wavekey =  @c_Wavekey
         ORDER BY WD.Wavedetailkey
      END 

      IF @c_AllocateType = 'WAVE'
      BEGIN
         IF NOT EXISTS( SELECT 1 FROM WAVEDETAIL WITH (NOLOCK)
                        WHERE WaveKey = @c_WaveKey )
         BEGIN
            SET @n_continue = 3
            SET @n_err = 555753
            SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err)
                          + ': No Orders to allocate by Wave. (lsp_WaveAllocation)'
            EXEC [WM].[lsp_WriteError_List] 
                  @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
               ,  @c_TableName   = @c_TableName
               ,  @c_SourceType  = @c_SourceType
               ,  @c_Refkey1     = @c_WaveKey
               ,  @c_Refkey2     = @c_Loadkey
               ,  @c_Refkey3     = ''
               ,  @c_WriteType   = 'ERROR' 
               ,  @n_err2        = @n_err 
               ,  @c_errmsg2     = @c_errmsg 
               ,  @b_Success     = @b_Success   OUTPUT 
               ,  @n_err         = @n_err       OUTPUT 
               ,  @c_errmsg      = @c_errmsg    OUTPUT 
         END

         SET @c_Facility = ''
         SET @c_Storerkey= ''
         SELECT TOP 1 
                 @c_Facility = OH.Facility
               , @c_Storerkey= OH.Storerkey
         FROM WAVEDETAIL WD WITH (NOLOCK)
         JOIN ORDERS OH WITH (NOLOCK) ON WD.Orderkey = OH.Orderkey
         WHERE WD.Wavekey =  @c_Wavekey
         ORDER BY WD.Wavedetailkey

         SELECT @c_WaveConsoAllocation  = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'WaveConsoAllocation')
         SELECT @c_LoadConsoAllocation  = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'LoadConsoAllocation')
         SELECT @c_ContinueAllocUnLoadSO= dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'ContinueAllocUnLoadSO')
         SELECT @c_ValidateCancelDate   = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'ValidateCancelDate')

         --(Wan07) - START
         SELECT @c_StrategykeyParm = ISNULL(w.Strategykey,'')              
               ,@c_WaveType        = w.WaveType
         FROM dbo.WAVE AS w WITH (NOLOCK) 
         WHERE w.WaveKey = @c_WaveKey
         
         IF @c_StrategykeyParm <> ''
         BEGIN
            SELECT @c_WaveAllowSelectStrategy = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'WaveAllowSelectStrategy')
            
            IF @c_WaveAllowSelectStrategy = '1'
            BEGIN
               SET @n_Cnt = 0
               SELECT TOP 1 @n_Cnt = IIF(c.Storerkey = @c_Storerkey OR c.Storerkey = '', 1, 0)
               FROM dbo.CODELKUP AS c WITH (NOLOCK)
               WHERE c.LISTNAME = 'WAVESTRGY'
               AND c.Code = @c_StrategykeyParm
               ORDER BY 1
            
               IF @n_Cnt = 0
               BEGIN
                  SET @n_Continue = 3
                  SET @n_Err = 555771
                  SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Invalid Strategy: ' + @c_StrategykeyParm
                                + '. Please check ListName ''WAVESTRGY''. (lsp_WaveAllocation) |' + @c_StrategykeyParm  

                  EXEC [WM].[lsp_WriteError_List] 
                           @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                        ,  @c_TableName   = @c_TableName
                        ,  @c_SourceType  = @c_SourceType
                        ,  @c_Refkey1     = @c_WaveKey
                        ,  @c_Refkey2     = @c_Loadkey
                        ,  @c_Refkey3     = ''
                        ,  @c_WriteType   = 'ERROR' 
                        ,  @n_err2        = @n_err 
                        ,  @c_errmsg2     = @c_errmsg 
                        ,  @b_Success     = @b_Success   
                        ,  @n_err         = @n_err       
                        ,  @c_errmsg      = @c_errmsg  
               END
            END
            ELSE
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 555770
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Storer Config ''WaveAllowSelectStrategy'' is turn off.'
                             + 'Storer: ' + @c_Storerkey + ' is disallow to select wave''s strategy. (lsp_WaveAllocation) |' + @c_Storerkey  

               EXEC [WM].[lsp_WriteError_List] 
                        @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                     ,  @c_TableName   = @c_TableName
                     ,  @c_SourceType  = @c_SourceType
                     ,  @c_Refkey1     = @c_WaveKey
                     ,  @c_Refkey2     = @c_Loadkey
                     ,  @c_Refkey3     = ''
                     ,  @c_WriteType   = 'ERROR' 
                     ,  @n_err2        = @n_err 
                     ,  @c_errmsg2     = @c_errmsg 
                     ,  @b_Success     = @b_Success   
                     ,  @n_err         = @n_err       
                     ,  @c_errmsg      = @c_errmsg  
               
            END
         END
         
         IF @c_StrategykeyParm = ''
         BEGIN
            SELECT @c_WaveGetStrategyByType = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'WaveGetStrategyByType')
            
            IF @c_WaveGetStrategyByType = '1'
            BEGIN
               SELECT TOP 1 @c_StrategykeyParm = IIF(c.Storerkey = @c_Storerkey OR c.Storerkey = '', c.Long, '')
               FROM dbo.CODELKUP AS c WITH (NOLOCK)
               JOIN dbo.Strategy AS s WITH (NOLOCK) ON c.Long = s.StrategyKey
               WHERE c.ListName = 'WaveType'
               AND c.Code = @c_WaveType
               ORDER BY 1 DESC
               
               IF @c_StrategykeyParm = ''
               BEGIN
                  SET @n_Continue = 3
                  SET @n_Err = 555772
                  SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Invalid Wave type''s Strategy.'
                                + 'Please check Long value for listname ''WAVETYPE''. (lsp_WaveAllocation)'   

                  EXEC [WM].[lsp_WriteError_List] 
                        @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                     ,  @c_TableName   = @c_TableName
                     ,  @c_SourceType  = @c_SourceType
                     ,  @c_Refkey1     = @c_WaveKey
                     ,  @c_Refkey2     = @c_Loadkey
                     ,  @c_Refkey3     = ''
                     ,  @c_WriteType   = 'ERROR' 
                     ,  @n_err2        = @n_err 
                     ,  @c_errmsg2     = @c_errmsg 
                     ,  @b_Success     = @b_Success   
                     ,  @n_err         = @n_err       
                     ,  @c_errmsg      = @c_errmsg       
               END
            END
         END

         --(Wan07) - END
         
         BEGIN TRY
            EXEC  [dbo].[isp_WaveCheckAllocateMode_Wrapper]  
                 @c_WaveKey      = @c_WaveKey   
               , @c_allocatemode = @c_allocatemode OUTPUT  
               , @b_Success      = @b_Success      OUTPUT
               , @n_Err          = @n_Err          OUTPUT 
               , @c_ErrMsg       = @c_ErrMsg       OUTPUT 
         END TRY
         BEGIN CATCH
            SET @n_Err = 555754
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Executing isp_WaveCheckAllocateMode_Wrapper. (lsp_WaveAllocation)'   
                           + '(' + @c_ErrMsg + ')' 
               EXEC [WM].[lsp_WriteError_List] 
                     @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                  ,  @c_TableName   = @c_TableName
                  ,  @c_SourceType  = @c_SourceType
                  ,  @c_Refkey1     = @c_WaveKey
                  ,  @c_Refkey2     = @c_Loadkey
                  ,  @c_Refkey3     = ''
                  ,  @c_WriteType   = 'ERROR' 
                  ,  @n_err2        = @n_err 
                  ,  @c_errmsg2     = @c_errmsg 
                  ,  @b_Success     = @b_Success   OUTPUT 
                  ,  @n_err         = @n_err       OUTPUT 
                  ,  @c_errmsg      = @c_errmsg    OUTPUT                                  
         END CATCH
            
         IF @b_Success = 0 OR @n_Err <> 0
         BEGIN
            SET @n_Continue = 3
         END
         
         --NJOW01 S
         IF @c_AllocateType = 'WAVE'  
         BEGIN         	  
            IF (@c_WaveConsoAllocation  = '1' OR @c_allocatemode = '#WC') AND @c_AllocateMode NOT IN('#DC','#LC') 
            BEGIN
               SET @c_allocatemode = '#WC'
            END
            ELSE IF @c_LoadConsoAllocation = '1' AND @c_allocatemode <> '#DC'
            BEGIN
               SET @c_allocatemode = '#LC'
            END
            ELSE
            BEGIN
               SET @c_allocatemode = '#DC'
            END
         END   
         ELSE --NJOW01 E
         BEGIN         	  
            IF @c_WaveConsoAllocation <> '1' AND @c_LoadConsoAllocation <> '1'
            BEGIN
               SET @c_allocatemode = '#DC'
            END
            
            IF @c_LoadConsoAllocation = '1' AND @c_allocatemode <> '#DC'
            BEGIN
               SET @c_allocatemode = '#LC'
            END
            
            IF @c_WaveConsoAllocation = '1' OR @c_allocatemode = '#WC'
            BEGIN
               SET @c_allocatemode = '#WC'
            END
         END
         
         IF @c_allocatemode = '#LC' 
         BEGIN
            IF @c_ContinueAllocUnLoadSO <> '1' AND
               NOT EXISTS (   SELECT 1
                                 FROM WAVEDETAIL WD WITH (NOLOCK)
                                 JOIN LOADPLANDETAIL LPD WITH (NOLOCK) ON (WD.Orderkey = LPD.Orderkey)
                                 WHERE WD.WaveKey = @c_WaveKey
                              )
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 555755
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': No Load # found for Wave: ' + @c_WaveKey
                              + '. Generate loadPlan before Wave Allocation. (lsp_WaveAllocation)'  
                              + '|' + @c_WaveKey

               EXEC [WM].[lsp_WriteError_List] 
                     @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                  ,  @c_TableName   = @c_TableName
                  ,  @c_SourceType  = @c_SourceType
                  ,  @c_Refkey1     = @c_WaveKey
                  ,  @c_Refkey2     = @c_Loadkey
                  ,  @c_Refkey3     = ''
                  ,  @c_WriteType   = 'ERROR' 
                  ,  @n_err2        = @n_err 
                  ,  @c_errmsg2     = @c_errmsg 
                  ,  @b_Success     = @b_Success   OUTPUT 
                  ,  @n_err         = @n_err       OUTPUT 
                  ,  @c_errmsg      = @c_errmsg    OUTPUT                                                        
            END

            --IF @c_ContinueAllocUnLoadSO <> '1'
            --BEGIN
            --   IF EXISTS ( SELECT 1
            --               FROM WAVEDETAIL WD WITH (NOLOCK)
            --               JOIN ORDERS OH WITH (NOLOCK) ON WD.Orderkey = OH.Orderkey
            --               WHERE WD.Wavekey =  @c_Wavekey
            --               AND  (OH.Loadkey = '' OR OH.Loadkey IS NULL)
            --               )
            --   BEGIN
            --      SET @n_Continue = 3
            --      SET @n_Err = 555756
            --      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Missing Loadkey for Load Conso Allocation. (lsp_WaveAllocation)' 
                   
            --      EXEC [WM].[lsp_WriteError_List] 
            --            @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
            --         ,  @c_TableName   = @c_TableName
            --         ,  @c_SourceType  = @c_SourceType
            --         ,  @c_Refkey1     = @c_WaveKey
            --         ,  @c_Refkey2     = @c_Loadkey
            --         ,  @c_Refkey3     = ''
            --         ,  @c_WriteType   = 'ERROR' 
            --         ,  @n_err2        = @n_err 
            --         ,  @c_errmsg2     = @c_errmsg 
            --         ,  @b_Success     = @b_Success   OUTPUT 
            --         ,  @n_err         = @n_err       OUTPUT 
            --         ,  @c_errmsg      = @c_errmsg    OUTPUT  
            --   END
            --END

            IF @c_ValidateCancelDate = '1'
            BEGIN
               IF EXISTS ( SELECT 1
                           FROM WAVEDETAIL WD WITH (NOLOCK)
                           JOIN ORDERS OH WITH (NOLOCK) ON WD.Orderkey = OH.Orderkey
                           WHERE WD.Wavekey =  @c_Wavekey
                           AND   OH.DeliveryDate < CONVERT(DATE, GETDATE())
                           )
               BEGIN
                  SET @c_ErrMsg = 'Order Cancelled date < today date found.'
                   
                  EXEC [WM].[lsp_WriteError_List] 
                        @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                     ,  @c_TableName   = @c_TableName
                     ,  @c_SourceType  = @c_SourceType
                     ,  @c_Refkey1     = @c_WaveKey
                     ,  @c_Refkey2     = @c_Loadkey
                     ,  @c_Refkey3     = ''
                     ,  @c_WriteType   = 'WARNING' 
                     ,  @n_err2        = @n_err 
                     ,  @c_errmsg2     = @c_errmsg 
                     ,  @b_Success     = @b_Success   OUTPUT 
                     ,  @n_err         = @n_err       OUTPUT 
                     ,  @c_errmsg      = @c_errmsg    OUTPUT                   
               END
            END
         END
      END

      IF @c_AllocateType = 'LOAD' 
      BEGIN 
         IF NOT EXISTS( SELECT 1 FROM LOADPLANDETAIL LPD WITH (NOLOCK)
                        WHERE Loadkey = @c_LoadKey )
         BEGIN
            SET @n_continue = 3
            SET @n_err = 555757
            SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err)
                          + ': No Orders to allocate By Load. (lsp_WaveAllocation)'
            EXEC [WM].[lsp_WriteError_List] 
                  @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
               ,  @c_TableName   = @c_TableName
               ,  @c_SourceType  = @c_SourceType
               ,  @c_Refkey1     = @c_WaveKey
               ,  @c_Refkey2     = @c_Loadkey
               ,  @c_Refkey3     = ''
               ,  @c_WriteType   = 'ERROR' 
               ,  @n_err2        = @n_err 
               ,  @c_errmsg2     = @c_errmsg 
               ,  @b_Success     = @b_Success   OUTPUT 
               ,  @n_err         = @n_err       OUTPUT 
               ,  @c_errmsg      = @c_errmsg    OUTPUT  
         END

         SET @c_Facility = ''
         SET @c_Storerkey= ''
         SELECT TOP 1 
                 @c_Facility = OH.Facility
               , @c_Storerkey= OH.Storerkey
               , @c_FinalizeFlag = ISNULL(LP.FinalizeFlag,'')
               , @c_SuperOrderFlag=ISNULL(LP.SuperOrderFlag,'')
         FROM LOADPLAN LP WITH (NOLOCK)
         JOIN LOADPLANDETAIL LPD WITH (NOLOCK) ON LP.Loadkey = LPD.Loadkey
         JOIN ORDERS OH WITH (NOLOCK) ON LPD.Orderkey = OH.Orderkey
         WHERE LPD.Loadkey =  @c_Loadkey
         ORDER BY LPD.LoadLineNumber

         SELECT @c_FinalizeLP  = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'FinalizeLP')
         SELECT @c_ValidateCancelDate = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'ValidateCancelDate')

         IF @c_FinalizeLP = '1' AND @c_FinalizeFlag <> 'Y'
         BEGIN
            SET @n_continue = 3
            SET @n_err = 555758
            SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err)
                           + ': Please Finalize Loadplan before proceeding to allocate by Load. (lsp_WaveAllocation)'

            EXEC [WM].[lsp_WriteError_List] 
                  @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
               ,  @c_TableName   = @c_TableName
               ,  @c_SourceType  = @c_SourceType
               ,  @c_Refkey1     = @c_WaveKey
               ,  @c_Refkey2     = @c_Loadkey
               ,  @c_Refkey3     = ''
               ,  @c_WriteType   = 'ERROR' 
               ,  @n_err2        = @n_err 
               ,  @c_errmsg2     = @c_errmsg 
               ,  @b_Success     = @b_Success   OUTPUT 
               ,  @n_err         = @n_err       OUTPUT 
               ,  @c_errmsg      = @c_errmsg    OUTPUT    
            GOTO EXIT_SP
         END

         SET @c_allocatemode = '#DC'
         IF @c_SuperOrderFlag = 'Y'
         BEGIN
            SET @c_allocatemode = '#LC'
         END

         IF @c_ValidateCancelDate = '1'
         BEGIN
            IF EXISTS ( SELECT 1
                        FROM LOADPLANDETAIL LPD WITH (NOLOCK)
                        JOIN ORDERS OH WITH (NOLOCK) ON LPD.Orderkey = OH.Orderkey
                        WHERE LPD.Loadkey =  @c_Loadkey
                        AND   OH.DeliveryDate < CONVERT(DATE, GETDATE())
                        )
            BEGIN
               SET @c_ErrMsg = 'Order Cancelled date < today date found.'
               
               EXEC [WM].[lsp_WriteError_List] 
                     @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                  ,  @c_TableName   = @c_TableName
                  ,  @c_SourceType  = @c_SourceType
                  ,  @c_Refkey1     = @c_WaveKey
                  ,  @c_Refkey2     = @c_Loadkey
                  ,  @c_Refkey3     = ''
                  ,  @c_WriteType   = 'WARNING' 
                  ,  @n_err2        = @n_err 
                  ,  @c_errmsg2     = @c_errmsg 
                  ,  @b_Success     = @b_Success   OUTPUT 
                  ,  @n_err         = @n_err       OUTPUT 
                  ,  @c_errmsg      = @c_errmsg    OUTPUT               
            END
         END
      END  
         
      IF @c_AllocateType = 'DYNAMICPICK'
      BEGIN
         IF NOT EXISTS( SELECT 1 FROM WAVEDETAIL WD WITH (NOLOCK)
                        JOIN LOADPLANDETAIL LPD WITH (NOLOCK) ON (WD.Orderkey = LPD.Orderkey)
                        WHERE Wavekey = @c_Wavekey )
         BEGIN
            SET @n_continue = 3
            SET @n_Err = 555759
            SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err)
                          + ': Loadplan is required to process Dynamic Pick Allocation. (lsp_WaveAllocation)'
            EXEC [WM].[lsp_WriteError_List] 
                  @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
               ,  @c_TableName   = @c_TableName
               ,  @c_SourceType  = @c_SourceType
               ,  @c_Refkey1     = @c_WaveKey
               ,  @c_Refkey2     = @c_Loadkey
               ,  @c_Refkey3     = ''
               ,  @c_WriteType   = 'ERROR' 
               ,  @n_err2        = @n_err 
               ,  @c_errmsg2     = @c_errmsg 
               ,  @b_Success     = @b_Success   OUTPUT 
               ,  @n_err         = @n_err       OUTPUT 
               ,  @c_errmsg      = @c_errmsg    OUTPUT       
         END
      END 
      
      IF @n_continue = 3
      BEGIN
         GOTO EXIT_SP
      END       
      
      ------------------------------------------
      -- PreAllocate Validation For Wave - START
      ------------------------------------------
      SELECT @c_AllocateValidationRules = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'PreAllocateExtendedValidation') 

      IF @c_AllocateValidationRules <> ''
      BEGIN
         IF EXISTS ( SELECT 1
                     FROM CODELKUP CL WITH (NOLOCK)  
                     WHERE CL.ListName = @c_AllocateValidationRules
                   )
         BEGIN

            SET @c_SQLVLD = N'EXEC isp_Allocate_ExtendedValidation @c_Orderkey = @c_ValidateOrderKey'
                            + ', @c_Loadkey = @c_ValidateLoadkey'
                            + ', @c_Wavekey = @c_ValidateWaveKey'
                            + ', @c_Mode = ''PRE'''  
                            + ', @c_AllocateValidationRules=@c_AllocateValidationRules'
                            + ', @b_Success = @b_Success OUTPUT'
                            --+ ', @n_Err = @n_Err OUTPUT'                             --(Wan02)
                            + ', @c_ErrMsg = @c_ErrMsg OUTPUT ' 
         END
         ELSE
         BEGIN
            --SET @c_AllocateValidationRules = 'isp_Allocate_ExtendedValidation'         --(Wan02)
            IF EXISTS (SELECT 1 FROM sys.objects WHERE name = RTRIM(@c_AllocateValidationRules) AND type = 'P')            
            BEGIN  
               SET @c_SQLVLD = N'EXEC ' + @c_AllocateValidationRules 
                              + ' @c_Orderkey = @c_ValidateOrderKey'
                              + ', @c_Loadkey = @c_ValidateLoadkey'
                              + ', @c_Wavekey = @c_ValidateWaveKey'
                              + ', @b_Success = @b_Success OUTPUT'
                              + ', @n_Err = @n_Err OUTPUT'
                              + ', @c_ErrMsg = @c_ErrMsg OUTPUT ' 
            END
            ELSE 
            BEGIN 
               SET @c_AllocateValidationRules = ''
            END   
         END
      END

      IF @c_AllocateType IN ( 'UCC', 'DYNAMICPICK' ) OR (@c_AllocateType = 'WAVE' AND @c_allocatemode = '#WC')
      BEGIN
         IF @c_AllocateValidationRules <> ''
         BEGIN
            SET @c_ValidateOrderKey = ''
            SET @c_ValidateLoadkey  = ''
            SET @c_ValidateWaveKey  = @c_WaveKey
            SET @c_SQLVLDParms = N'@c_ValidateOrderKey   NVARCHAR(10)'
                               + ',@c_ValidateLoadkey    NVARCHAR(10)'
                               + ',@c_ValidateWaveKey    NVARCHAR(10)'
                               + ',@c_AllocateValidationRules NVARCHAR(30)'
                               + ',@b_Success            INT OUTPUT'
                               + ',@n_Err                INT OUTPUT'
                               + ',@c_ErrMsg             NVARCHAR(255) OUTPUT' 
            EXEC sp_ExecuteSql @c_SQLVLD
                              ,@c_SQLVLDParms
                              ,@c_ValidateOrderKey   
                              ,@c_ValidateLoadkey
                              ,@c_ValidateWaveKey    
                              ,@c_AllocateValidationRules
                              ,@b_Success    OUTPUT          
                              ,@n_Err        OUTPUT                                     
                              ,@c_ErrMsg     OUTPUT
            IF @b_Success = 0
            BEGIN
               SET @n_continue = 3
               SET @n_Err = 555751
               SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err)
                             + ': Pre Allocate Validate Fail - Wave #: ' + @c_WaveKey
                             + '. (lsp_WaveAllocation)'
                             + '|' + @c_WaveKey
               EXEC [WM].[lsp_WriteError_List] 
                     @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                  ,  @c_TableName   = @c_TableName
                  ,  @c_SourceType  = @c_SourceType
                  ,  @c_Refkey1     = @c_WaveKey
                  ,  @c_Refkey2     = @c_Loadkey
                  ,  @c_Refkey3     = ''
                  ,  @c_WriteType   = 'ERROR' 
                  ,  @n_err2        = @n_err 
                  ,  @c_errmsg2     = @c_errmsg 
                  ,  @b_Success     = @b_Success   OUTPUT 
                  ,  @n_err         = @n_err       OUTPUT 
                  ,  @c_errmsg      = @c_errmsg    OUTPUT       
               GOTO EXIT_SP
            END
         END                                        
      END
      ------------------------------------------
      -- PreAllocate Validation For Wave - END
      ------------------------------------------          
      --(Wan01) - START
      SELECT TOP 1                                                         --(Wan05)
             @c_APP_DB_Name     = ISNULL(qcfg.APP_DB_Name,'')  
          ,  @c_DataStream      = qcfg.DataStream     --BACKENDALC
          ,  @n_ThreadPerAcct   = qcfg.ThreadPerAcct  
          ,  @n_ThreadPerStream = qcfg.ThreadPerStream  
          ,  @n_MilisecondDelay = qcfg.MilisecondDelay  
          ,  @c_IP              = qcfg.[IP]           --Service Box IP
          ,  @c_PORT            = qcfg.[PORT]         --xx801: Backend Allocation, xx:please refer to country's used xx number.
          ,  @c_IniFilePath     = qcfg.IniFilePath    --'C:\COMObject\GenericTCPSocketClient\config.ini'
          ,  @c_CmdType         = qcfg.CmdType        --'SQL' 
          ,  @c_TaskType        = qcfg.TaskType       --'O'
          ,  @n_Priority        = qcfg.[Priority]     -- O
      FROM  dbo.QCmd_TransmitlogConfig qcfg WITH (NOLOCK)  
      WHERE qcfg.TableName      = 'MANUALALLOC'
      AND   qcfg.[App_Name]     = 'WMS'  
      AND   qcfg.StorerKey      IN ( @c_Storerkey, 'ALL')                  --(Wan08)(Wan05)
      AND   qcfg.Facility       IN ( @c_Facility,  'ALL', '')              --(Wan08)(Wan05)      
      ORDER BY CASE WHEN qcfg.StorerKey = @c_Storerkey AND                 --(Wan08)(Wan05)   
                         qcfg.Facility  = @c_Facility                      --(Wan08)
                    THEN 1                                                 --(Wan05)
                    WHEN qcfg.StorerKey = @c_Storerkey AND                 --(Wan08)(Wan05)   
                         qcfg.Facility  IN ( 'ALL', '')                    --(Wan08)
                    THEN 2                                                 --(Wan08)(Wan05)  
                    WHEN qcfg.StorerKey = 'ALL' AND                        --(Wan08)(Wan05)   
                         qcfg.Facility  = @c_Facility                      --(Wan08)
                    THEN 6                                                 --(Wan08)(Wan05)  
                    WHEN qcfg.StorerKey = 'ALL' AND                        --(Wan08)    
                         qcfg.Facility  IN ( 'ALL', '')                    --(Wan08)
                    THEN 7                                                 --(Wan08)     
                    ELSE 9                                                 --(Wan08)(Wan05)
                    END                                                    --(Wan05)
            , qcfg.RowRefNo                                                --(Wan05)
      
      IF @c_PORT = ''
      BEGIN
         SET @n_Err = 555769
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Q-Commander TCP Socket not setup! (lsp_WaveAllocation)'
                        + '|' + @c_WaveKey
         EXEC [WM].[lsp_WriteError_List] 
               @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
            ,  @c_TableName   = @c_TableName
            ,  @c_SourceType  = @c_SourceType
            ,  @c_Refkey1     = @c_WaveKey
            ,  @c_Refkey2     = @c_Loadkey
            ,  @c_Refkey3     = ''
            ,  @c_WriteType   = 'MESSAGE' 
            ,  @n_err2        = @n_err 
            ,  @c_errmsg2     = @c_errmsg 
            ,  @b_Success     = @b_Success   OUTPUT 
            ,  @n_err         = @n_err       OUTPUT 
            ,  @c_errmsg      = @c_errmsg    OUTPUT 
                                           
         GOTO EXIT_SP
      END
      --(Wan01) - END
      
      --(Wan06) - START
      SET @n_Cnt = 0
      SELECT @n_Cnt = 1 
      FROM dbo.TCPSocket_QueueTask AS tsqt (NOLOCK)
      WHERE tsqt.TransmitLogKey = @c_WaveKey
      AND tsqt.DataStream = @c_DataStream
      AND tsqt.[Port] = @c_Port
      AND tsqt.[Status] IN ('0', '1')
      
      --PRINT  @n_Cnt 0 

      IF @n_Cnt = 1 
      BEGIN
         SET @c_ErrMsg = 'Wave #: ' + @c_WaveKey
                        + ' had submitted to QCommander & Pending allocation/In Progress. (lsp_WaveAllocation)'   

         EXEC [WM].[lsp_WriteError_List] 
               @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
            ,  @c_TableName   = @c_TableName
            ,  @c_SourceType  = @c_SourceType
            ,  @c_Refkey1     = @c_WaveKey
            ,  @c_Refkey2     = @c_Loadkey
            ,  @c_Refkey3     = ''
            ,  @c_WriteType   = 'MESSAGE' 
            ,  @n_err2        = @n_err 
            ,  @c_errmsg2     = @c_errmsg 
            ,  @b_Success     = @b_Success   OUTPUT 
            ,  @n_err         = @n_err       OUTPUT 
            ,  @c_errmsg      = @c_errmsg    OUTPUT  
         GOTO EXIT_SP
      END
      --(Wan06) - END
           
      --(Wan03) - START             --(Wan07) Get on Above
      --SET @c_StrategykeyParm = ''      
      --SELECT @c_StrategykeyParm = ISNULL(w.Strategykey,'')
      --FROM dbo.WAVE AS w WITH (NOLOCK)
      --WHERE w.WaveKey = @c_Wavekey
      --(Wan03) - END
      
      WAVE_ALLOCATION:
         IF @c_AllocateType = 'WAVE' 
         BEGIN
            IF @c_allocatemode = '#WC'
            BEGIN
               SET @n_Cnt = 0 
               PRINT 'Wave Allocation has been started...'
               /*--(Wan06) - START
               --(Wan01) - START
               SET @c_DataStream = 'WaveALC'              
               --SELECT @n_Cnt = 1 
               --FROM IDSAllocationPool WITH (NOLOCK)
               --WHERE Sourcekey = @c_WaveKey
               --AND SourceType = 'WP'
               --AND Status IN ('0', '1')
            
               SELECT @n_Cnt = 1 
               FROM dbo.TCPSocket_QueueTask AS tsqt (NOLOCK)
               WHERE tsqt.TransmitLogKey = @c_WaveKey
               AND tsqt.DataStream = @c_DataStream
               AND tsqt.[Port] = @c_Port
               AND tsqt.[Status] IN ('0', '1')
               --(Wan06) - END
               --*/
               
               IF @n_Cnt = 1 
               BEGIN
                  SET @c_ErrMsg = 'WP - Wave #: ' + @c_WaveKey
                                + ' had submitted to QCommander & Pending allocation/In Progress. (lsp_WaveAllocation)'   

                  EXEC [WM].[lsp_WriteError_List] 
                        @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                     ,  @c_TableName   = @c_TableName
                     ,  @c_SourceType  = @c_SourceType
                     ,  @c_Refkey1     = @c_WaveKey
                     ,  @c_Refkey2     = @c_Loadkey
                     ,  @c_Refkey3     = ''
                     ,  @c_WriteType   = 'MESSAGE' 
                     ,  @n_err2        = @n_err 
                     ,  @c_errmsg2     = @c_errmsg 
                     ,  @b_Success     = @b_Success   OUTPUT 
                     ,  @n_err         = @n_err       OUTPUT 
                     ,  @c_errmsg      = @c_errmsg    OUTPUT  
                  GOTO EXIT_SP
               END

               SET @c_ExecCmd = '[dbo].[ispWaveProcessing] @c_WaveKey=''' + @c_WaveKey + ''',@b_Success=1,@n_Err=0,@c_ErrMsg='''''
                              + ',@c_strategykeyparm=''' + @c_StrategykeyParm + ''''                                                --(Wan03)
               SET @c_ExecCmd = '[WM].[lsp_AllocationProcessing_Wrapper] @c_AllocCmd=N''' + REPLACE(@c_ExecCmd,'''','''''') + ''', @c_Wavekey=N''' + @c_Wavekey + ''''   --(Wan05)
                              + ', @b_Success=1, @n_Err=0, @c_ErrMsg='''',@c_UserName =N''' + @c_UserName + ''''            
                PRINT @c_ExecCmd;  
               BEGIN TRY
                  --INSERT INTO IDSAllocationPool
                  --   (
                  --      Sourcekey
                  --   ,  SourceType
                  --   ,  Wavekey
                  --   ,  AllocateCmd
                  --   ,  WinComputerName
                  --   )
                  --VALUES
                  --   (
                  --      @c_WaveKey
                  --   ,  'WP'
                  --   ,  @c_WaveKey
                  --   ,  @c_ExecCmd
                  --   , ''
                  --   )
                  
                  EXEC isp_QCmd_SubmitTaskToQCommander     
                           @cTaskType         = @c_TaskType -- D=By Datastream, T=Transmitlog, O=Others           
                        ,  @cStorerKey        = @c_StorerKey                                                
                        ,  @cDataStream       = @c_DataStream                                                     
                        ,  @cCmdType          = @c_CmdType                                                    
                        ,  @cCommand          = @c_ExecCmd                                                  
                        ,  @cTransmitlogKey   = @c_Wavekey                                         
                        ,  @nThreadPerAcct    = @n_ThreadPerAcct                                                    
                        ,  @nThreadPerStream  = @n_ThreadPerStream                                                          
                        ,  @nMilisecondDelay  = @n_MilisecondDelay                                                          
                        ,  @nSeq              = 1                           
                        ,  @cIP               = @c_IP                                             
                        ,  @cPORT             = @c_PORT                                                    
                        ,  @cIniFilePath      = @c_IniFilePath           
                        ,  @cAPPDBName        = @c_APP_DB_Name                                                   
                        ,  @bSuccess          = @b_Success   OUTPUT      
                        ,  @nErr              = @n_Err       OUTPUT      
                        ,  @cErrMsg           = @c_ErrMsg    OUTPUT 
                        ,  @nPriority         = @n_Priority             --(Wan04)             
               END TRY
               BEGIN CATCH
                  SET @n_Err = 555760
                  SET @c_ErrMsg = ERROR_MESSAGE()
                  SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Submit Wave #: ' + @c_WaveKey
                                 + ' to QCommander Fail - Wave Consolidate. (lsp_WaveAllocation)'   
                                 + '(' + @c_ErrMsg + ')' 
                                 + '|' + @c_WaveKey
                                   
                  --EXEC [WM].[lsp_WriteError_List] 
                  --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                  --   ,  @c_TableName   = @c_TableName
                  --   ,  @c_SourceType  = @c_SourceType
                  --   ,  @c_Refkey1     = @c_WaveKey
                  --   ,  @c_Refkey2     = @c_Loadkey
                  --   ,  @c_Refkey3     = ''
                  --   ,  @c_WriteType   = 'ERROR' 
                  --   ,  @n_err2        = @n_err 
                  --   ,  @c_errmsg2     = @c_errmsg 
                  --   ,  @b_Success     = @b_Success   OUTPUT 
                  --   ,  @n_err         = @n_err       OUTPUT 
                  --   ,  @c_errmsg      = @c_errmsg    OUTPUT    
                  --GOTO EXIT_SP                                     
               END CATCH
                                                
               IF @b_Success = 0
               BEGIN
                  SET @n_Continue = 3
               END
            
               IF @n_Continue = 3
               BEGIN
                     EXEC [WM].[lsp_WriteError_List] 
                        @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                     ,  @c_TableName   = @c_TableName
                     ,  @c_SourceType  = @c_SourceType
                     ,  @c_Refkey1     = @c_WaveKey
                     ,  @c_Refkey2     = @c_Loadkey
                     ,  @c_Refkey3     = ''
                     ,  @c_WriteType   = 'ERROR' 
                     ,  @n_err2        = @n_err 
                     ,  @c_errmsg2     = @c_errmsg 
                     ,  @b_Success     = @b_Success   OUTPUT 
                     ,  @n_err         = @n_err       OUTPUT 
                     ,  @c_errmsg      = @c_errmsg    OUTPUT                                
               END
               --(Wan01) - END
               GOTO EXIT_SP
            END

            CREATE TABLE #tWAVEDETAIL
               (  RowRef      INT            NOT NULL IDENTITY(1,1)
               ,  Orderkey    NVARCHAR(10)   NOT NULL DEFAULT ('')
               )

            SET @c_Facility = ''
            SET @c_Storerkey= ''
            SELECT TOP 1 
                    @c_Facility = OH.Facility
                  , @c_Storerkey= OH.Storerkey
            FROM WAVEDETAIL WD WITH (NOLOCK)
            JOIN ORDERS OH WITH (NOLOCK) ON WD.Orderkey = OH.Orderkey
            WHERE WD.Wavekey =  @c_Wavekey
            ORDER BY WD.Wavedetailkey

            SELECT @c_SPName = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'WaveALOrderSort_SP')

            IF @c_SPName <> ''
            BEGIN
               IF EXISTS (SELECT 1 FROM sys.objects WHERE name = RTRIM(@c_SPName) AND type = 'P')
               BEGIN
                  SET @c_SQL = N'EXEC ' + @c_SPName + ' @c_WaveKey = @c_Wavekey'
                  SET @c_SQLParms = N'@c_WaveKey   NVARCHAR(10)'

                  INSERT INTO #tWAVEDETAIL (Orderkey)
                  EXEC sp_ExecuteSQL @c_SQL
                                    ,@c_SQLParms
                                    ,@c_Wavekey            

               END
            END

            IF NOT EXISTS (SELECT 1 FROM #tWAVEDETAIL)
            BEGIN
               INSERT INTO #tWAVEDETAIL (Orderkey)      
               SELECT WD.Orderkey
               FROM WAVEDETAIL WD WITH (NOLOCK)
               WHERE WD.WaveKey = @c_WaveKey
               ORDER BY WD.WaveDetailKey
            END

            IF @c_allocatemode = '#LC'
            BEGIN
               SET @CUR_WAVELOAD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT DISTINCT 
                     Loadkey  = CASE WHEN LPD.Loadkey IS NULL THEN '' ELSE LPD.Loadkey END
                  ,  Orderkey = CASE WHEN LPD.Loadkey IS NULL THEN WD.Orderkey ELSE '' END
                  ,  SortLoad = CASE WHEN LPD.Loadkey IS NULL THEN 9 ELSE 1 END 
               FROM WAVEDETAIL WD WITH (NOLOCK)
               JOIN #tWAVEDETAIL T WITH (NOLOCK) ON (WD.Orderkey = T.Orderkey)
               LEFT JOIN LOADPLANDETAIL LPD WITH (NOLOCK) ON (WD.Orderkey = LPD.Orderkey)
               WHERE WD.WaveKey = @c_WaveKey
               ORDER BY SortLoad
                     ,  Orderkey               

               OPEN @CUR_WAVELOAD
      
               FETCH NEXT FROM @CUR_WAVELOAD INTO @c_Loadkey
                                                , @c_Orderkey
                                                , @n_SortLoad                                                                                   
                                       
               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  IF @c_AllocateValidationRules <> ''
                  BEGIN
                     SET @c_ValidateOrderKey= CASE WHEN @c_OrderKey = '' THEN '' ELSE @c_OrderKey END
                     SET @c_ValidateLoadkey = CASE WHEN @c_Loadkey  = '' THEN '' ELSE @c_Loadkey END
                     SET @c_ValidateWaveKey = ''

                     SET @c_SQLVLDParms = N'@c_ValidateOrderKey   NVARCHAR(10)'
                                        + ',@c_ValidateLoadkey    NVARCHAR(10)'
                                        + ',@c_ValidateWaveKey    NVARCHAR(10)'
                                        + ',@c_AllocateValidationRules NVARCHAR(30)'
                                        + ',@b_Success            INT OUTPUT'
                                        + ',@n_Err                INT OUTPUT'
                                        + ',@c_ErrMsg             NVARCHAR(255) OUTPUT' 
                     EXEC sp_ExecuteSql @c_SQLVLD
                                       ,@c_SQLVLDParms
                                       ,@c_ValidateOrderKey   
                                       ,@c_ValidateLoadkey
                                       ,@c_ValidateWaveKey    
                                       ,@c_AllocateValidationRules
                                       ,@b_Success    OUTPUT          
                                       ,@n_Err        OUTPUT                                     
                                       ,@c_ErrMsg     OUTPUT
                     IF @b_Success = 0
                     BEGIN
                        SET @n_continue = 3
                        SET @n_Err = 555752
                        SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err)
                                      + ': Pre Allocate Validate Fail - ' 
                                      + CASE WHEN @c_Loadkey  = '' THEN 'Order #: ' + @c_Orderkey ELSE 'Load #: ' + @c_Loadkey END
                                      + '. (lsp_WaveAllocation)'
                                      + '|' + CASE WHEN @c_Loadkey  = '' THEN 'Order #: ' + @c_Orderkey ELSE 'Load #: ' + @c_Loadkey END
                 
                        EXEC [WM].[lsp_WriteError_List] 
                              @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                           ,  @c_TableName   = @c_TableName
                           ,  @c_SourceType  = @c_SourceType
                           ,  @c_Refkey1     = @c_WaveKey
                           ,  @c_Refkey2     = @c_Loadkey
                           ,  @c_Refkey3     = ''
                           ,  @c_WriteType   = 'ERROR' 
                           ,  @n_err2        = @n_err 
                           ,  @c_errmsg2     = @c_errmsg 
                           ,  @b_Success     = @b_Success   OUTPUT 
                           ,  @n_err         = @n_err       OUTPUT 
                           ,  @c_errmsg      = @c_errmsg    OUTPUT       
                        GOTO NEXT_WAVELOAD
                     END
                  END                      

                  SET @n_Cnt = 0
               
               
                  --(Wan06) - START
                  /*
                  --(Wan01) - START
                  IF @c_Loadkey = ''             
                  BEGIN
                     SET @c_DataStream = 'ORDAlc'
                     SET @c_TransmitLogKey = @c_Orderkey 
                  --   --SELECT @n_Cnt = 1 
                  --   --FROM IDSAllocationPool WITH (NOLOCK)
                  --   --WHERE Sourcekey = @c_Orderkey
                  --   --AND SourceType = 'O'
                  --   --AND Status IN ('0', '1')
                  END
                  ELSE
                  BEGIN
                     SET @c_DataStream = 'LOADAlc'
                     SET @c_TransmitLogKey = @c_Loadkey  
                  --   --SELECT @n_Cnt = 1 
                  --   --FROM IDSAllocationPool WITH (NOLOCK)
                  --   --WHERE Sourcekey = @c_Loadkey
                  --   --AND SourceType = 'LP'
                  --   --AND Status IN ('0', '1')
                  END  
                  
                  SELECT @n_Cnt = 1 
                  FROM dbo.TCPSocket_QueueTask AS tsqt (NOLOCK)
                  WHERE tsqt.TransmitLogKey = @c_TransmitLogKey
                  AND tsqt.DataStream = @c_DataStream
                  AND tsqt.[Port] = @c_Port
                  AND tsqt.[Status] IN ('0', '1')
                  --(Wan06) - END
                  */
                  
                  IF @n_Cnt = 0
                  BEGIN
                     SET @c_ExecCmd = '[dbo].[nsp_OrderProcessing_Wrapper] @c_orderkey=''' + @c_orderkey + ''''
                                    + ',@c_oskey=''' + @c_Loadkey + ''''
                                    + ',@c_docarton=''N'''
                                    + ',@c_doroute=''N'''
                                    + ',@c_tblprefix=''XX'''
                                    + ',@c_extendparms=''WP'''
                                    + ',@c_strategykeyparm=''' + @c_StrategykeyParm + ''''               --(Wan03)
                     SET @c_ExecCmd = '[WM].[lsp_AllocationProcessing_Wrapper] @c_AllocCmd=N''' + REPLACE(@c_ExecCmd,'''','''''') + ''', @c_Wavekey=N''' + @c_Wavekey + ''''   --(Wan05)
                                    + ', @b_Success=1, @n_Err=0, @c_ErrMsg='''',@c_UserName =N''' + @c_UserName + ''''                  
                     BEGIN TRY
                        --INSERT INTO IDSAllocationPool
                        --   (
                        --      Sourcekey
                        --   ,  SourceType
                        --   ,  Wavekey
                        --   ,  AllocateCmd
                        --   ,  WinComputerName
                        --   )
                        --VALUES
                        --   (
                        --      CASE WHEN @c_Loadkey = '' THEN @c_Orderkey ELSE @c_Loadkey END
                        --   ,  CASE WHEN @c_Loadkey = '' THEN 'O' ELSE 'LP' END
                        --   ,  @c_WaveKey
                        --   ,  @c_ExecCmd
                        --   ,  ''
                        --   )
                           
                        EXEC isp_QCmd_SubmitTaskToQCommander     
                           @cTaskType         = @c_TaskType -- D=By Datastream, T=Transmitlog, O=Others           
                        ,  @cStorerKey        = @c_StorerKey                                                
                        ,  @cDataStream       = @c_DataStream                                                     
                        ,  @cCmdType          = @c_CmdType                                                    
                        ,  @cCommand          = @c_ExecCmd                                                  
                        ,  @cTransmitlogKey   = @c_WaveKey              --Wan06 --@c_TransmitLogKey                                          
                        ,  @nThreadPerAcct    = @n_ThreadPerAcct                                                    
                        ,  @nThreadPerStream  = @n_ThreadPerStream                                                          
                        ,  @nMilisecondDelay  = @n_MilisecondDelay                                                          
                        ,  @nSeq              = 1                           
                        ,  @cIP               = @c_IP                                             
                        ,  @cPORT             = @c_PORT                                                    
                        ,  @cIniFilePath      = @c_IniFilePath           
                        ,  @cAPPDBName        = @c_APP_DB_Name                                                   
                        ,  @bSuccess          = @b_Success   OUTPUT      
                        ,  @nErr              = @n_Err       OUTPUT      
                        ,  @cErrMsg           = @c_ErrMsg    OUTPUT 
                        ,  @nPriority         = @n_Priority             --(Wan04)
                     END TRY

                     BEGIN CATCH
                        SET @n_Continue = 3
                        SET @n_Err = 555761
                        SET @c_ErrMsg = ERROR_MESSAGE()
                        SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Submit '
                                       + CASE WHEN @c_Orderkey = '' THEN 'Load #: ' +  @c_Loadkey ELSE 'Order #: '  + @c_Orderkey END
                                       + ' to QCommander Fail - Load Consolidate. (lsp_WaveAllocation)'   
                                       + '(' + @c_ErrMsg + ')'  
                                      + '|' + CASE WHEN @c_Orderkey = '' THEN 'Load #: ' +  @c_Loadkey ELSE 'Order #: ' + @c_Orderkey END

                        --EXEC [WM].[lsp_WriteError_List] 
                        --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                        --   ,  @c_TableName   = @c_TableName
                        --   ,  @c_SourceType  = @c_SourceType
                        --   ,  @c_Refkey1     = @c_WaveKey
                        --   ,  @c_Refkey2     = @c_Loadkey
                        --   ,  @c_Refkey3     = ''
                        --   ,  @c_WriteType   = 'ERROR' 
                        --   ,  @n_err2        = @n_err 
                        --   ,  @c_errmsg2     = @c_errmsg 
                        --   ,  @b_Success     = @b_Success   OUTPUT 
                        --   ,  @n_err         = @n_err       OUTPUT 
                        --   ,  @c_errmsg      = @c_errmsg    OUTPUT                                       
                     END CATCH
                     
                     IF @b_Success = 0
                     BEGIN
                        SET @n_Continue = 3
                     END
            
                     IF @n_Continue = 3
                     BEGIN
                           EXEC [WM].[lsp_WriteError_List] 
                              @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                           ,  @c_TableName   = @c_TableName
                           ,  @c_SourceType  = @c_SourceType
                           ,  @c_Refkey1     = @c_WaveKey
                           ,  @c_Refkey2     = @c_Loadkey
                           ,  @c_Refkey3     = ''
                           ,  @c_WriteType   = 'ERROR' 
                           ,  @n_err2        = @n_err 
                           ,  @c_errmsg2     = @c_errmsg 
                           ,  @b_Success     = @b_Success   OUTPUT 
                           ,  @n_err         = @n_err       OUTPUT 
                           ,  @c_errmsg      = @c_errmsg    OUTPUT                                
                     END
                     --(Wan01) - END
                  END
                  ELSE
                  BEGIN
                     SET @c_ErrMsg = CASE WHEN @c_Orderkey = '' THEN 'LP - Load #: ' +  @c_Loadkey ELSE 'O - Order #: '  + @c_Orderkey END
                                    + ' had submitted to QCommander & Pending allocation/In Progress. (lsp_WaveAllocation)'   
                                    + '(' + @c_ErrMsg + ')' 
    
                     EXEC [WM].[lsp_WriteError_List] 
                           @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                        ,  @c_TableName   = @c_TableName
                        ,  @c_SourceType  = @c_SourceType
                        ,  @c_Refkey1     = @c_WaveKey
                        ,  @c_Refkey2     = @c_Loadkey
                        ,  @c_Refkey3     = ''
                        ,  @c_WriteType   = 'MESSAGE' 
                        ,  @n_err2        = @n_err 
                        ,  @c_errmsg2     = @c_errmsg 
                        ,  @b_Success     = @b_Success   OUTPUT 
                        ,  @n_err         = @n_err       OUTPUT 
                        ,  @c_errmsg      = @c_errmsg    OUTPUT  
                  END
                  NEXT_WAVELOAD:
                  FETCH NEXT FROM @CUR_WAVELOAD INTO @c_Loadkey
                                                   , @c_Orderkey 
                                                   , @n_SortLoad                                               
               END

               CLOSE @CUR_WAVELOAD
               DEALLOCATE @CUR_WAVELOAD

               GOTO EXIT_SP 
            END

            SET @c_Source = 'WP'

            SET @CUR_ORD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT RefLineNo= T.RowRef 
                 , Orderkey = WD.Orderkey 
            FROM WAVEDETAIL WD WITH (NOLOCK)
            JOIN #tWAVEDETAIL T WITH (NOLOCK) ON (WD.Orderkey = T.Orderkey)
            WHERE WD.WaveKey = @c_WaveKey
            ORDER BY T.RowRef
                  ,  WD.Orderkey 
                       
            GOTO DC_ALLOCATION
         END

      LOAD_ALLOCATION:
         IF @c_AllocateType = 'LOAD' 
         BEGIN
            IF @c_allocatemode = '#LC'  
            BEGIN
               IF @c_AllocateValidationRules <> ''
               BEGIN
                  SET @c_ValidateOrderKey = ''
                  SET @c_ValidateLoadkey  = @c_Loadkey  
                  SET @c_ValidateWaveKey  = ''

                  SET @c_SQLVLDParms= N'@c_ValidateOrderKey   NVARCHAR(10)'
                                    + ',@c_ValidateLoadkey    NVARCHAR(10)'
                                    + ',@c_ValidateWaveKey    NVARCHAR(10)'
                                    + ',@c_AllocateValidationRules NVARCHAR(30)'
                                    + ',@b_Success            INT OUTPUT'
                                    + ',@n_Err                INT OUTPUT'
                                    + ',@c_ErrMsg             NVARCHAR(255) OUTPUT'
                                     
                  EXEC sp_ExecuteSql @c_SQLVLD
                                    ,@c_SQLVLDParms
                                    ,@c_ValidateOrderKey   
                                    ,@c_ValidateLoadkey
                                    ,@c_ValidateWaveKey    
                                    ,@c_AllocateValidationRules
                                    ,@b_Success    OUTPUT          
                                    ,@n_Err        OUTPUT                                     
                                    ,@c_ErrMsg     OUTPUT
                  IF @b_Success = 0
                  BEGIN
                     SET @n_continue = 3
                     SET @n_Err = 555766
                     SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err)
                                   + ': Pre Allocate Validate Fail - Load #: ' + @c_Loadkey
                                   + '. (lsp_WaveAllocation)'
                                   + '|' + @c_Loadkey
                     EXEC [WM].[lsp_WriteError_List] 
                           @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                        ,  @c_TableName   = @c_TableName
                        ,  @c_SourceType  = @c_SourceType
                        ,  @c_Refkey1     = @c_WaveKey
                        ,  @c_Refkey2     = @c_Loadkey
                        ,  @c_Refkey3     = ''
                        ,  @c_WriteType   = 'ERROR' 
                        ,  @n_err2        = @n_err 
                        ,  @c_errmsg2     = @c_errmsg 
                        ,  @b_Success     = @b_Success   OUTPUT 
                        ,  @n_err         = @n_err       OUTPUT 
                        ,  @c_errmsg      = @c_errmsg    OUTPUT       
                     GOTO EXIT_SP
                  END
               END 
                   
               SET @n_Cnt = 0  
               --(Wan06) - START
               /*                 
               --(Wan01) - START
               SET @c_DataStream = 'LOADAlc'               
               --SELECT @n_Cnt = 1 
               --FROM IDSAllocationPool WITH (NOLOCK)
               --WHERE Sourcekey = @c_Loadkey
               --AND SourceType = 'LP'
               --AND Status IN ('0', '1')
            
               SELECT @n_Cnt = 1 
               FROM dbo.TCPSocket_QueueTask AS tsqt (NOLOCK)
               WHERE tsqt.TransmitLogKey = @c_Loadkey
               AND tsqt.DataStream = @c_DataStream
               AND tsqt.[Port] = @c_Port
               AND tsqt.[Status] IN ('0', '1')
               --(Wan06) - END
               */
               IF @n_Cnt = 1 
               BEGIN
                  SET @c_ErrMsg = 'LP - Loadkey #: ' + @c_Loadkey
                                 + ' had submitted to QCommander & Pending allocation/In Progress. (lsp_WaveAllocation)'   
                                 + '(' + @c_ErrMsg + ')' 

                  EXEC [WM].[lsp_WriteError_List] 
                        @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                     ,  @c_TableName   = @c_TableName
                     ,  @c_SourceType  = @c_SourceType
                     ,  @c_Refkey1     = @c_WaveKey
                     ,  @c_Refkey2     = @c_Loadkey
                     ,  @c_Refkey3     = ''
                     ,  @c_WriteType   = 'MESSAGE' 
                     ,  @n_err2        = @n_err 
                     ,  @c_errmsg2     = @c_errmsg 
                     ,  @b_Success     = @b_Success   OUTPUT 
                     ,  @n_err         = @n_err       OUTPUT 
                     ,  @c_errmsg      = @c_errmsg    OUTPUT  
                  GOTO EXIT_SP
               END
 
               SET @c_ExecCmd = '[dbo].[nsp_OrderProcessing_Wrapper] @c_orderkey='''''
                              + ',@c_oskey=''' + @c_Loadkey + ''''
                              + ',@c_docarton=''N'''
                              + ',@c_doroute=''N'''
                              + ',@c_tblprefix=''XX'''
                              + ',@c_extendparms='''''
                              + ',@c_strategykeyparm=''' + @c_StrategykeyParm + ''''               --(Wan03)
               SET @c_ExecCmd = '[WM].[lsp_AllocationProcessing_Wrapper] @c_AllocCmd=N''' + REPLACE(@c_ExecCmd,'''','''''') + ''', @c_Wavekey=N''' + @c_Wavekey + ''''   --(Wan05)
                              + ', @b_Success=1, @n_Err=0, @c_ErrMsg='''',@c_UserName =N''' + @c_UserName + ''''                  
               BEGIN TRY
                  --INSERT INTO IDSAllocationPool
                  --   (
                  --      Sourcekey
                  --   ,  SourceType
                  --   ,  Wavekey
                  --   ,  AllocateCmd
                  --   ,  WinComputerName
                  --   )
                  --VALUES
                  --   (
                  --      @c_Loadkey
                  --   ,  'LP'
                  --   ,  @c_WaveKey
                  --   ,  @c_ExecCmd
                  --   ,  ''
                  --   )
                  
                  EXEC isp_QCmd_SubmitTaskToQCommander     
                           @cTaskType         = @c_TaskType -- D=By Datastream, T=Transmitlog, O=Others           
                        ,  @cStorerKey        = @c_StorerKey                                                
                        ,  @cDataStream       = @c_DataStream                                                                  
                        ,  @cCmdType          = @c_CmdType                                                    
                        ,  @cCommand          = @c_ExecCmd                                                  
                        ,  @cTransmitlogKey   = @c_WaveKey              --(Wan06)   --@c_Loadkey                                            
                        ,  @nThreadPerAcct    = @n_ThreadPerAcct                                                    
                        ,  @nThreadPerStream  = @n_ThreadPerStream                                                          
                        ,  @nMilisecondDelay  = @n_MilisecondDelay                                                          
                        ,  @nSeq              = 1                           
                        ,  @cIP               = @c_IP                                             
                        ,  @cPORT             = @c_PORT                                                    
                        ,  @cIniFilePath      = @c_IniFilePath           
                        ,  @cAPPDBName        = @c_APP_DB_Name                                                   
                        ,  @bSuccess          = @b_Success   OUTPUT      
                        ,  @nErr              = @n_Err       OUTPUT      
                        ,  @cErrMsg           = @c_ErrMsg    OUTPUT 
                        ,  @nPriority         = @n_Priority             --(Wan04)
               END TRY

               BEGIN CATCH
                  SET @n_Continue = 3
                  SET @n_Err = 555762
                  SET @c_ErrMsg = ERROR_MESSAGE()
                  SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Submit Load #: ' + @c_Loadkey
                                 + ' to QCommander Fail - Load Consolidate. (lsp_WaveAllocation)'
                                 + '(' + @c_ErrMsg + ')'  
                                 + '|' + @c_Loadkey                                
                                
                  --EXEC [WM].[lsp_WriteError_List] 
                  --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                  --   ,  @c_TableName   = @c_TableName
                  --   ,  @c_SourceType  = @c_SourceType
                  --   ,  @c_Refkey1     = @c_WaveKey
                  --   ,  @c_Refkey2     = @c_Loadkey
                  --   ,  @c_Refkey3     = ''
                  --   ,  @c_WriteType   = 'ERROR' 
                  --   ,  @n_err2        = @n_err 
                  --   ,  @c_errmsg2     = @c_errmsg 
                  --   ,  @b_Success     = @b_Success   OUTPUT 
                  --   ,  @n_err         = @n_err       OUTPUT 
                  --   ,  @c_errmsg      = @c_errmsg    OUTPUT                                             
                  --GOTO EXIT_SP  
               END CATCH
               
               IF @b_Success = 0
               BEGIN
                  SET @n_Continue = 3
               END
            
               IF @n_Continue = 3
               BEGIN
                     EXEC [WM].[lsp_WriteError_List] 
                        @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                     ,  @c_TableName   = @c_TableName
                     ,  @c_SourceType  = @c_SourceType
                     ,  @c_Refkey1     = @c_WaveKey
                     ,  @c_Refkey2     = @c_Loadkey
                     ,  @c_Refkey3     = ''
                     ,  @c_WriteType   = 'ERROR' 
                     ,  @n_err2        = @n_err 
                     ,  @c_errmsg2     = @c_errmsg 
                     ,  @b_Success     = @b_Success   OUTPUT 
                     ,  @n_err         = @n_err       OUTPUT 
                     ,  @c_errmsg      = @c_errmsg    OUTPUT                                
               END
               --(Wan01) - END

               GOTO EXIT_SP 
            END

            SET @c_Source = 'LP'
            SET @c_Facility = ''
            SET @c_Storerkey= ''
            SELECT TOP 1 
                    @c_Facility = OH.Facility
                  , @c_Storerkey= OH.Storerkey
                  , @c_FinalizeFlag = LP.FinalizeFlag
                  , @c_SuperOrderFlag=LP.SuperOrderFlag
            FROM LOADPLAN LP WITH (NOLOCK)
            JOIN LOADPLANDETAIL LPD WITH (NOLOCK) ON LP.Loadkey = LPD.Loadkey
            JOIN ORDERS OH WITH (NOLOCK) ON LPD.Orderkey = OH.Orderkey
            WHERE LPD.Loadkey =  @c_Loadkey
            ORDER BY LPD.LoadLineNumber

            SELECT @c_AllowLPAlloc4DiscreteOrd  = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'AllowLPAlloc4DiscreteOrd')

            SET @CUR_ORD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT RefLineNo= LPD.LoadLineNumber  
                 , Orderkey = LPD.Orderkey 
            FROM LOADPLANDETAIL LPD WITH (NOLOCK)
            JOIN ORDERS OH WITH (NOLOCK) ON (LPD.Orderkey = OH.Orderkey)
            WHERE LPD.Loadkey = @c_Loadkey
            AND (@c_AllowLPAlloc4DiscreteOrd = '1' OR 
                (@c_AllowLPAlloc4DiscreteOrd <> '1' AND OH.[Type] NOT IN ('I','M') AND ISNULL(OH.UserDefine08,'') <> 'Y')
                )
            ORDER BY LPD.LoadLineNumber  

            GOTO DC_ALLOCATION
         END

      DC_ALLOCATION:
         IF @c_AllocateType NOT IN ( 'UCC', 'DYNAMICPICK' )
         BEGIN
            IF @c_allocatemode = '#DC'
            BEGIN
               OPEN @CUR_ORD
      
               FETCH NEXT FROM @CUR_ORD INTO @c_ReflineNo, @c_Orderkey                                                                                   
                                       
               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  IF @c_AllocateValidationRules <> ''
                  BEGIN
                     SET @c_ValidateOrderKey = @c_Orderkey        --2021-06-15 Fixed
                     SET @c_ValidateLoadkey  = ''                 --2021-06-15 Fixed
                     SET @c_ValidateWaveKey  = ''

                     SET @c_SQLVLDParms= N'@c_ValidateOrderKey    NVARCHAR(10)'
                                       + ',@c_ValidateLoadkey     NVARCHAR(10)'
                                       + ',@c_ValidateWaveKey     NVARCHAR(10)'
                                       + ',@c_AllocateValidationRules NVARCHAR(30)'
                                       + ',@b_Success             INT OUTPUT'
                                       + ',@n_Err                 INT OUTPUT'
                                       + ',@c_ErrMsg              NVARCHAR(255) OUTPUT' 
                     EXEC sp_ExecuteSql @c_SQLVLD
                                       ,@c_SQLVLDParms
                                       ,@c_ValidateOrderKey   
                                       ,@c_ValidateLoadkey 
                                       ,@c_ValidateWaveKey    
                                       ,@c_AllocateValidationRules
                                       ,@b_Success    OUTPUT          
                                       ,@n_Err        OUTPUT                                     
                                       ,@c_ErrMsg     OUTPUT
                     IF @b_Success = 0
                     BEGIN
                        SET @n_continue = 3
                        SET @n_Err = 555767
                        SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err)
                                      + ': Pre Allocate Validate Fail - Order #: ' + @c_Orderkey
                                      + '. (lsp_WaveAllocation)'
                                      + '|' + @c_Orderkey
                        EXEC [WM].[lsp_WriteError_List] 
                              @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                           ,  @c_TableName   = @c_TableName
                           ,  @c_SourceType  = @c_SourceType
                           ,  @c_Refkey1     = @c_WaveKey
                           ,  @c_Refkey2     = @c_Loadkey
                           ,  @c_Refkey3     = ''
                           ,  @c_WriteType   = 'ERROR' 
                           ,  @n_err2        = @n_err 
                           ,  @c_errmsg2     = @c_errmsg 
                           ,  @b_Success     = @b_Success   OUTPUT 
                           ,  @n_err         = @n_err       OUTPUT 
                           ,  @c_errmsg      = @c_errmsg    OUTPUT       
                        GOTO EXIT_SP
                     END
                  END 

                  SET @n_Cnt = 0 

                  --(Wan06) - START
                  /*
                  --(Wan01) - START
                  SET @c_DataStream = 'ORDAlcDC'             
                  --SELECT @n_Cnt = 1 
                  --FROM IDSAllocationPool WITH (NOLOCK)
                  --WHERE Sourcekey = @c_Orderkey
                  --AND SourceType = 'DC'
                  --AND Status IN ('0', '1')
            
                  SELECT @n_Cnt = 1 
                  FROM dbo.TCPSocket_QueueTask AS tsqt (NOLOCK)
                  WHERE tsqt.TransmitLogKey = @c_Orderkey
                  AND tsqt.DataStream = @c_DataStream
                  AND tsqt.[Port] = @c_Port
                  AND tsqt.[Status] IN ('0', '1')
                  --(Wan06) - END
                  */
                  
                  IF @n_Cnt = 0 
                  BEGIN
                     SET @c_ExecCmd = '[dbo].[nsp_OrderProcessing_Wrapper] @c_orderkey='''+ @c_Orderkey +''''
                                    + ',@c_oskey='''''
                                    + ',@c_docarton=''N'''
                                    + ',@c_doroute=''N'''
                                    + ',@c_tblprefix=''XX'''
                                    + ',@c_extendparms='''+ @c_Source +''''
                                    + ',@c_strategykeyparm=''' + @c_StrategykeyParm + ''''               --(Wan03)
                     SET @c_ExecCmd = '[WM].[lsp_AllocationProcessing_Wrapper] @c_AllocCmd=N''' + REPLACE(@c_ExecCmd,'''','''''') + ''', @c_Wavekey=N''' + @c_Wavekey + ''''   --(Wan05)
                                    + ', @b_Success=1, @n_Err=0, @c_ErrMsg='''',@c_UserName =N''' + @c_UserName + ''''                  
                     BEGIN TRY
                        --INSERT INTO IDSAllocationPool
                        --   (
                        --      Sourcekey
                        --   ,  SourceType
                        --   ,  Wavekey
                        --   ,  AllocateCmd
                        --   ,  WinComputerName
                        --   )
                        --VALUES
                        --   (
                        --      @c_Orderkey
                        --   ,  'DC'
                        --   ,  @c_WaveKey
                        --   ,  @c_ExecCmd
                        --   ,  ''
                        --   )
                        EXEC isp_QCmd_SubmitTaskToQCommander     
                           @cTaskType         = @c_TaskType -- D=By Datastream, T=Transmitlog, O=Others           
                        ,  @cStorerKey        = @c_StorerKey                                                
                        ,  @cDataStream       = @c_DataStream                                                     
                        ,  @cCmdType          = @c_CmdType                                                    
                        ,  @cCommand          = @c_ExecCmd                                                  
                        ,  @cTransmitlogKey   = @c_WaveKey              --(Wan06) -- @c_Orderkey                                            
                        ,  @nThreadPerAcct    = @n_ThreadPerAcct                                                    
                        ,  @nThreadPerStream  = @n_ThreadPerStream                                                          
                        ,  @nMilisecondDelay  = @n_MilisecondDelay                                                          
                        ,  @nSeq              = 1                           
                        ,  @cIP               = @c_IP                                             
                        ,  @cPORT             = @c_PORT                                                    
                        ,  @cIniFilePath      = @c_IniFilePath           
                        ,  @cAPPDBName        = @c_APP_DB_Name                                                   
                        ,  @bSuccess          = @b_Success   OUTPUT      
                        ,  @nErr              = @n_Err       OUTPUT      
                        ,  @cErrMsg           = @c_ErrMsg    OUTPUT 
                        ,  @nPriority         = @n_Priority             --(Wan04)
                     END TRY

                     BEGIN CATCH
                        SET @n_Err = 555768
                        SET @c_ErrMsg = ERROR_MESSAGE()
                        SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Submit Order #: ' + @c_Orderkey 
                                      + ' to QCommander Fail - Order. (lsp_WaveAllocation)'
                                      + '(' + @c_ErrMsg + ')'  
                                      + '|' + @c_Orderkey                                    
                        --EXEC [WM].[lsp_WriteError_List] 
                        --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                        --   ,  @c_TableName   = @c_TableName
                        --   ,  @c_SourceType  = @c_SourceType
                        --   ,  @c_Refkey1     = @c_WaveKey
                        --   ,  @c_Refkey2     = @c_Loadkey
                        --   ,  @c_Refkey3     = ''
                        --   ,  @c_WriteType   = 'ERROR' 
                        --   ,  @n_err2        = @n_err 
                        --   ,  @c_errmsg2     = @c_errmsg 
                        --   ,  @b_Success     = @b_Success   OUTPUT 
                        --   ,  @n_err         = @n_err       OUTPUT 
                        --   ,  @c_errmsg      = @c_errmsg    OUTPUT                                     
                     END CATCH
                     
                     IF @b_Success = 0
                     BEGIN
                        SET @n_Continue = 3
                     END
            
                     IF @n_Continue = 3
                     BEGIN
                         EXEC [WM].[lsp_WriteError_List] 
                              @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                           ,  @c_TableName   = @c_TableName
                           ,  @c_SourceType  = @c_SourceType
                           ,  @c_Refkey1     = @c_WaveKey
                           ,  @c_Refkey2     = @c_Loadkey
                           ,  @c_Refkey3     = ''
                           ,  @c_WriteType   = 'ERROR' 
                           ,  @n_err2        = @n_err 
                           ,  @c_errmsg2     = @c_errmsg 
                           ,  @b_Success     = @b_Success   OUTPUT 
                           ,  @n_err         = @n_err       OUTPUT 
                           ,  @c_errmsg      = @c_errmsg    OUTPUT                                
                     END
                     --(Wan01) - END
                  END
                  ELSE
                  BEGIN
                     SET @c_ErrMsg = 'DC - Order #: ' + @c_Orderkey
                                    + ' had submitted to QCommander & Pending allocation/In Progress. (lsp_WaveAllocation)'   
                                    + '(' + @c_ErrMsg + ')' 

                     EXEC [WM].[lsp_WriteError_List] 
                           @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                        ,  @c_TableName   = @c_TableName
                        ,  @c_SourceType  = @c_SourceType
                        ,  @c_Refkey1     = @c_WaveKey
                        ,  @c_Refkey2     = @c_Loadkey
                        ,  @c_Refkey3     = ''
                        ,  @c_WriteType   = 'MESSAGE' 
                        ,  @n_err2        = @n_err 
                        ,  @c_errmsg2     = @c_errmsg 
                        ,  @b_Success     = @b_Success   OUTPUT 
                        ,  @n_err         = @n_err       OUTPUT 
                        ,  @c_errmsg      = @c_errmsg    OUTPUT  
                  END
                  NEXT_ORD:
                  FETCH NEXT FROM @CUR_ORD INTO @c_ReflineNo, @c_Orderkey 
               END
               CLOSE @CUR_ORD
               DEALLOCATE @CUR_ORD

               GOTO EXIT_SP 
            END
         END

      UCC_ALLOCATION:
         IF @c_AllocateType = 'UCC'
         BEGIN
            SET @n_Cnt = 0 
            --(Wan06) - START
            /*
            --(Wan01) - START
            SET @c_DataStream = 'WaveAlcUCC'              
            --SELECT @n_Cnt = 1 
            --FROM IDSAllocationPool WITH (NOLOCK)
            --WHERE Sourcekey = @c_WaveKey
            --AND SourceType = 'UCC'
            --AND Status IN ('0', '1')
            
            SELECT @n_Cnt = 1 
            FROM dbo.TCPSocket_QueueTask AS tsqt (NOLOCK)
            WHERE tsqt.TransmitLogKey = @c_WaveKey
            AND tsqt.DataStream = @c_DataStream
            AND tsqt.[Port] = @c_Port
            AND tsqt.[Status] IN ('0', '1')
            --(Wan06) - END
            */
                  
            IF @n_Cnt = 1 
            BEGIN
               SET @c_ErrMsg = 'UCC - Wave #: ' + @c_WaveKey
                              + ' had submitted to QCommander & Pending allocation/In Progress. (lsp_WaveAllocation)'   
                              + '(' + @c_ErrMsg + ')' 

               EXEC [WM].[lsp_WriteError_List] 
                     @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                  ,  @c_TableName   = @c_TableName
                  ,  @c_SourceType  = @c_SourceType
                  ,  @c_Refkey1     = @c_WaveKey
                  ,  @c_Refkey2     = @c_Loadkey
                  ,  @c_Refkey3     = ''
                  ,  @c_WriteType   = 'MESSAGE' 
                  ,  @n_err2        = @n_err 
                  ,  @c_errmsg2     = @c_errmsg 
                  ,  @b_Success     = @b_Success   OUTPUT 
                  ,  @n_err         = @n_err       OUTPUT 
                  ,  @c_errmsg      = @c_errmsg    OUTPUT  
               GOTO EXIT_SP
            END

            SET @c_ExecCmd = '[dbo].[ispWaveReplenUCCAlloc] @c_WaveKey=''' + @c_WaveKey + ''',@b_Success=1,@n_Err=0,@c_ErrMsg='''''
            SET @c_ExecCmd = '[WM].[lsp_AllocationProcessing_Wrapper] @c_AllocCmd=N''' + REPLACE(@c_ExecCmd,'''','''''') + ''', @c_Wavekey=N''' + @c_Wavekey + ''''   --(Wan05)
                           + ', @b_Success=1, @n_Err=0, @c_ErrMsg='''',@c_UserName =N''' + @c_UserName + ''''     
            BEGIN TRY
               --INSERT INTO IDSAllocationPool
               --   (
               --      Sourcekey
               --   ,  SourceType
               --   ,  Wavekey
               --   ,  AllocateCmd
               --   ,  WinComputerName
               --   )
               --VALUES
               --   (
               --      @c_WaveKey
               --   ,  'UCC'
               --   ,  @c_WaveKey
               --   ,  @c_ExecCmd
               --   ,  ''
               --   )
               
               EXEC isp_QCmd_SubmitTaskToQCommander     
                     @cTaskType         = @c_TaskType -- D=By Datastream, T=Transmitlog, O=Others           
                  ,  @cStorerKey        = @c_StorerKey                                                
                  ,  @cDataStream       = @c_DataStream                                                     
                  ,  @cCmdType          = @c_CmdType                                                    
                  ,  @cCommand          = @c_ExecCmd                                                  
                  ,  @cTransmitlogKey   = @c_Wavekey                                            
                  ,  @nThreadPerAcct    = @n_ThreadPerAcct                                                    
                  ,  @nThreadPerStream  = @n_ThreadPerStream                                                          
                  ,  @nMilisecondDelay  = @n_MilisecondDelay                                                          
                  ,  @nSeq              = 1                           
                  ,  @cIP               = @c_IP                                             
                  ,  @cPORT             = @c_PORT                                                    
                  ,  @cIniFilePath      = @c_IniFilePath           
                  ,  @cAPPDBName        = @c_APP_DB_Name                                                   
                  ,  @bSuccess          = @b_Success   OUTPUT      
                  ,  @nErr              = @n_Err       OUTPUT      
                  ,  @cErrMsg           = @c_ErrMsg    OUTPUT
                  ,  @nPriority         = @n_Priority             --(Wan04)    
            END TRY

            BEGIN CATCH
               SET @n_Continue = 3
               SET @n_Err = 555764
               SET @c_ErrMsg = ERROR_MESSAGE()
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Submit Wave #: ' + @c_WaveKey
                              + ' to QCommander Fail - UCC. (lsp_WaveAllocation)'   
                              + '(' + @c_ErrMsg + ')'
                              + '|' + @c_WaveKey
                                                            
               --EXEC [WM].[lsp_WriteError_List] 
               --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
               --   ,  @c_TableName   = @c_TableName
               --   ,  @c_SourceType  = @c_SourceType
               --   ,  @c_Refkey1     = @c_WaveKey
               --   ,  @c_Refkey2     = @c_Loadkey
               --   ,  @c_Refkey3     = ''
               --   ,  @c_WriteType   = 'ERROR' 
               --   ,  @n_err2        = @n_err 
               --   ,  @c_errmsg2     = @c_errmsg 
               --   ,  @b_Success     = @b_Success   OUTPUT 
               --   ,  @n_err         = @n_err       OUTPUT 
               --   ,  @c_errmsg      = @c_errmsg    OUTPUT    
               --GOTO EXIT_SP                                    
            END CATCH
                 
            IF @b_Success = 0
            BEGIN
               SET @n_Continue = 3
            END
            
            IF @n_Continue = 3
            BEGIN
                EXEC [WM].[lsp_WriteError_List] 
                     @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                  ,  @c_TableName   = @c_TableName
                  ,  @c_SourceType  = @c_SourceType
                  ,  @c_Refkey1     = @c_WaveKey
                  ,  @c_Refkey2     = @c_Loadkey
                  ,  @c_Refkey3     = ''
                  ,  @c_WriteType   = 'ERROR' 
                  ,  @n_err2        = @n_err 
                  ,  @c_errmsg2     = @c_errmsg 
                  ,  @b_Success     = @b_Success   OUTPUT 
                  ,  @n_err         = @n_err       OUTPUT 
                  ,  @c_errmsg      = @c_errmsg    OUTPUT                                
            END
            --(Wan01) - END     
            GOTO EXIT_SP 
         END

      DYNAMICPICK_ALLOCATION:
         IF @c_AllocateType = 'DYNAMICPICK'
         BEGIN
            SET @n_Cnt = 0 
            
            --(Wan06) - START
            /*
            --(Wan01) - START
            SET @c_DataStream       = 'WaveAlcDPP'              
            --SELECT @n_Cnt = 1 
            --FROM IDSAllocationPool WITH (NOLOCK)
            --WHERE Sourcekey = @c_WaveKey
            --AND SourceType = 'DYNAMICPICK'
            --AND Status IN ('0', '1')
            
            SELECT @n_Cnt = 1 
            FROM dbo.TCPSocket_QueueTask AS tsqt (NOLOCK)
            WHERE tsqt.TransmitLogKey = @c_WaveKey
            AND tsqt.DataStream = @c_DataStream
            AND tsqt.[Port] = @c_Port
            AND tsqt.[Status] IN ('0', '1')
            */
            --(Wan06) - END
            
            IF @n_Cnt = 1 
            BEGIN
               SET @c_ErrMsg = 'DYNAMICPICK - Wave #: ' + @c_WaveKey
                              + ' had submitted to QCommander & Pending allocation/In Progress. (lsp_WaveAllocation)'   
                              + '(' + @c_ErrMsg + ')'

               EXEC [WM].[lsp_WriteError_List] 
                     @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                  ,  @c_TableName   = @c_TableName
                  ,  @c_SourceType  = @c_SourceType
                  ,  @c_Refkey1     = @c_WaveKey
                  ,  @c_Refkey2     = @c_Loadkey
                  ,  @c_Refkey3     = ''
                  ,  @c_WriteType   = 'MESSAGE' 
                  ,  @n_err2        = @n_err 
                  ,  @c_errmsg2     = @c_errmsg 
                  ,  @b_Success     = @b_Success   OUTPUT 
                  ,  @n_err         = @n_err       OUTPUT 
                  ,  @c_errmsg      = @c_errmsg    OUTPUT  
               GOTO EXIT_SP
            END
             
            SET @c_DynamicPickLocStart = ''
            SELECT @c_DynamicPickLocStart = ISNULL(WH.Userdefine01,'')
            FROM WAVE WH WITH (NOLOCK) 
            WHERE WH.Wavekey = @c_Wavekey

            SET @c_ExecCmd = '[dbo].[ispWaveDynamicPickUCCAlloc] @c_WaveKey=''' + @c_WaveKey + ''''
                           + ',@c_DPLoc_Start=''' + @c_DynamicPickLocStart + ''''
                           + ',@b_Success=1'
                           + ',@n_Err=0'
                           + ',@c_ErrMsg='''''
            SET @c_ExecCmd = '[WM].[lsp_AllocationProcessing_Wrapper] @c_AllocCmd=N''' + REPLACE(@c_ExecCmd,'''','''''') + ''', @c_Wavekey=N''' + @c_Wavekey + ''''   --(Wan05)
                           + ', @b_Success=1, @n_Err=0, @c_ErrMsg='''',@c_UserName =N''' + @c_UserName + ''''                               
            BEGIN TRY
               --INSERT INTO IDSAllocationPool
               --   (
               --      Sourcekey
               --   ,  SourceType
               --   ,  Wavekey
               --   ,  AllocateCmd
               --   ,  WinComputerName
               --   )
               --VALUES
               --   (
               --      @c_WaveKey
               --   ,  'DYNAMICPICK'
               --   ,  @c_WaveKey
               --   ,  @c_ExecCmd
               --   ,  ''
               --   )
               
               EXEC isp_QCmd_SubmitTaskToQCommander     
                     @cTaskType         = @c_TaskType -- D=By Datastream, T=Transmitlog, O=Others           
                  ,  @cStorerKey        = @c_StorerKey                                                
                  ,  @cDataStream       = @c_DataStream                                                     
                  ,  @cCmdType          = @c_CmdType                                                    
                  ,  @cCommand          = @c_ExecCmd                                                  
                  ,  @cTransmitlogKey   = @c_Wavekey                                            
                  ,  @nThreadPerAcct    = @n_ThreadPerAcct                                                    
                  ,  @nThreadPerStream  = @n_ThreadPerStream                                                          
                  ,  @nMilisecondDelay  = @n_MilisecondDelay                                                          
                  ,  @nSeq              = 1                           
                  ,  @cIP               = @c_IP                                             
                  ,  @cPORT             = @c_PORT                                                    
                  ,  @cIniFilePath      = @c_IniFilePath           
                  ,  @cAPPDBName        = @c_APP_DB_Name                                                   
                  ,  @bSuccess          = @b_Success   OUTPUT      
                  ,  @nErr              = @n_Err       OUTPUT      
                  ,  @cErrMsg           = @c_ErrMsg    OUTPUT 
                  ,  @nPriority         = @n_Priority             --(Wan04)   
            END TRY

            BEGIN CATCH
               SET @n_Continue = 3
               SET @n_Err = 555765
               SET @c_ErrMsg = ERROR_MESSAGE()
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Submit Wave #: ' + @c_WaveKey
                              + ' to QCommander  Fail - DYNAMICPICK . (lsp_WaveAllocation)'   
                              + '(' + @c_ErrMsg + ')'
                              + '|' + @c_WaveKey                            
                                    
            END CATCH
            
            IF @b_Success = 0
            BEGIN
               SET @n_Continue = 3
            END
            
            IF @n_Continue = 3
            BEGIN
                EXEC [WM].[lsp_WriteError_List] 
                     @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                  ,  @c_TableName   = @c_TableName
                  ,  @c_SourceType  = @c_SourceType
                  ,  @c_Refkey1     = @c_WaveKey
                  ,  @c_Refkey2     = @c_Loadkey
                  ,  @c_Refkey3     = ''
                  ,  @c_WriteType   = 'ERROR' 
                  ,  @n_err2        = @n_err 
                  ,  @c_errmsg2     = @c_errmsg 
                  ,  @b_Success     = @b_Success   OUTPUT 
                  ,  @n_err         = @n_err       OUTPUT 
                  ,  @c_errmsg      = @c_errmsg    OUTPUT                                
            END
            --(Wan01) - END
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
   IF OBJECT_ID('tempdb..#tWAVEDETAIL','u') IS NOT NULL
   BEGIN
      DROP TABLE #tWAVEDETAIL
   END 

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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_WaveAllocation'
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