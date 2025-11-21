SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: lsp_WAV_PopulateSO_Wrapper                          */                                                                                  
/* Creation Date: 2021-03-09                                            */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-2619 - UAT CN Wave Control  Wave No Add Order Function */
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
/* 2021-03-09  Wan      1.0   Created                                   */ 
/* 2021-08-13  Wan01    1.1   JSM-14065 - Duplicate Sequence #          */    
/************************************************************************/                                                                                  
CREATE PROC [WM].[lsp_WAV_PopulateSO_Wrapper]                                                                                                                     
      @c_Wavekey              NVARCHAR(10)         --Wavekey to Populate to 
   ,  @c_OrderKeyList         NVARCHAR(4000) = ''  -- Order Keys seperated by '|' if multiple orders to populate
   ,  @b_Success              INT = 1           OUTPUT  
   ,  @n_err                  INT = 0           OUTPUT                                                                                                             
   ,  @c_ErrMsg               NVARCHAR(255)= '' OUTPUT   
   ,  @c_UserName             NVARCHAR(128)= ''  
   ,  @n_ErrGroupKey          INT          = 0  OUTPUT                                                                                                                          
AS  
BEGIN                                                                                                                                                        
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF       

   DECLARE  @n_StartTCnt               INT = @@TRANCOUNT  
         ,  @n_Continue                INT = 1

         ,  @n_Batch                   INT = 0

         ,  @c_SQL                     NVARCHAR(4000) = ''
         ,  @c_SQL1                    NVARCHAR(4000) = ''
         ,  @c_SQLParms                NVARCHAR(4000) = ''

         ,  @c_TableName               NVARCHAR(50)   = 'WAVEDETAIL'
         ,  @c_SourceType              NVARCHAR(50)   = 'lsp_WAV_PopulateSO_Wrapper'
         ,  @c_WriteType               NVARCHAR(10)   = ''

         ,  @n_StorerCnt               INT            = 0
         ,  @n_facilityCnt             INT            = 0
         ,  @c_MaxStorer               NVARCHAR(15)   = ''
         ,  @c_MaxFacility             NVARCHAR(15)   = ''

         ,  @c_Facility                NVARCHAR(5)    = ''
         ,  @c_Storerkey               NVARCHAR(15)   = ''
         ,  @c_Orderkey                NVARCHAR(10)   = '' 
         ,  @c_ExternOrderkey          NVARCHAR(30)   = ''
         ,  @c_WavedetailKey           NVARCHAR(10)   = ''

   DECLARE  @t_Orders TABLE
         (  Orderkey    NVARCHAR(10)   NOT NULL DEFAULT ('')
         ,  Facility    NVARCHAR(5)    NOT NULL DEFAULT ('')
         ,  Storerkey   NVARCHAR(15)   NOT NULL DEFAULT ('')
         )

   SET @b_Success = 1
   SET @n_Err     = 0

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
   
   BEGIN TRY  
      SET @n_ErrGroupKey = 0

      INSERT INTO @t_Orders (Orderkey, Facility, Storerkey)
      SELECT SS.[Value]
            ,OH.Facility
            ,OH.Storerkey
      FROM STRING_SPLIT (@c_OrderkeyList, '|') SS
      JOIN ORDERS OH WITH (NOLOCK) ON SS.[Value] = OH.Orderkey
      GROUP BY SS.[Value]
            ,OH.Facility
            ,OH.Storerkey
      ORDER BY SS.[Value]

      SET @c_Facility = ''
      SET @c_Storerkey= ''
      SELECT TOP 1
               @c_Facility = OH.Facility
            ,  @c_Storerkey= OH.Storerkey
      FROM WAVEDETAIL WD WITH (NOLOCK)
      JOIN ORDERS OH WITH (NOLOCK) ON WD.Orderkey = OH.Orderkey
      WHERE WD.Wavekey = @c_Wavekey

      SELECT @n_StorerCnt  = COUNT(DISTINCT t.Storerkey)
            ,@n_facilityCnt= COUNT(DISTINCT t.Facility)
            ,@c_MaxStorer  = ISNULL(MAX(t.Storerkey),'')
            ,@c_MaxFacility= ISNULL(MAX(t.Facility),'')
            ,@n_Batch      = COUNT(1)
      FROM @t_Orders t

      IF @n_StorerCnt > 1 OR @n_facilityCnt > 1 OR @c_MaxStorer <> @c_Storerkey OR @c_MaxFacility <> @c_Facility
      BEGIN
         SET @n_Continue = 3
         SET @n_Err      = 559251
         SET @c_errmsg   = 'Different Storer/facility orders are not allowed in a wave. (lsp_WAV_PopulateSO_Wrapper)'

         EXEC [WM].[lsp_WriteError_List] 
            @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
         ,  @c_TableName   = @c_TableName
         ,  @c_SourceType  = @c_SourceType
         ,  @c_Refkey1     = @c_Wavekey
         ,  @c_Refkey2     = ''
         ,  @c_Refkey3     = ''
         ,  @c_WriteType   = 'ERROR' 
         ,  @n_err2        = @n_err 
         ,  @c_errmsg2     = @c_errmsg 
         ,  @b_Success     = @b_Success   
         ,  @n_err         = @n_err       
         ,  @c_errmsg      = @c_errmsg    
      END 

      IF @n_Continue = 3
      BEGIN
         GOTO EXIT_SP
      END

      BEGIN TRY
         EXECUTE nspg_Getkey  
              @KeyName       = 'WavedetailKey'  
            , @fieldlength   = 10  
            , @keystring     = @c_WavedetailKey OUTPUT  
            , @b_Success     = @b_Success       OUTPUT  
            , @n_err         = @n_Err           OUTPUT  
            , @c_errmsg      = @c_ErrMsg        OUTPUT 
            , @b_resultset   = 0 
            , @n_batch       = @n_batch 
      END TRY
      BEGIN CATCH
         SET @n_Err    = 559252
         SET @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err) + ': Error Executing nspg_Getkey - Wavedetailkey. (lsp_WAV_PopulateSO_Wrapper)'
      END CATCH

      IF @n_Err <> 0
      BEGIN
         SET @n_Continue = 3

         EXEC [WM].[lsp_WriteError_List] 
            @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
         ,  @c_TableName   = @c_TableName
         ,  @c_SourceType  = @c_SourceType
         ,  @c_Refkey1     = @c_Wavekey
         ,  @c_Refkey2     = ''
         ,  @c_Refkey3     = ''
         ,  @c_WriteType   = 'ERROR' 
         ,  @n_err2        = @n_err 
         ,  @c_errmsg2     = @c_errmsg 
         ,  @b_Success     = @b_Success   
         ,  @n_err         = @n_err       
         ,  @c_errmsg      = @c_errmsg    

         GOTO EXIT_SP
      END
         
      BEGIN TRY
         INSERT INTO WAVEDETAIL ( WavedetailKey, Wavekey, Orderkey )    
         SELECT 
               WavedetailKey = RIGHT( '0000000000' 
                             +  CAST( (CAST(@c_WavedetailKey AS INT) - @n_Batch ) + ROW_NUMBER()      --(Wan01)
                                OVER (ORDER BY t.OrderKey) AS NVARCHAR), 10)                          --(Wan01)
            ,  Wavekey = @c_Wavekey
            ,  t.OrderKey
         FROM @t_Orders t
      END TRY
      BEGIN CATCH
         SET @n_Continue = 3
         SET @n_Err = 559253
         
         SELECT ERROR_MESSAGE()
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err) + ': Insert Into Wavedetail table Fail. (lsp_WAV_PopulateSO_Wrapper)'
                       + ' ( SQLSvr MESSAGE=' + ERROR_MESSAGE() + ' ) '

         EXEC [WM].[lsp_WriteError_List] 
            @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
         ,  @c_TableName   = @c_TableName
         ,  @c_SourceType  = @c_SourceType
         ,  @c_Refkey1     = @c_Wavekey
         ,  @c_Refkey2     = ''
         ,  @c_Refkey3     = ''
         ,  @c_WriteType   = 'ERROR' 
         ,  @n_err2        = @n_err 
         ,  @c_errmsg2     = @c_errmsg 
         ,  @b_Success     = @b_Success   
         ,  @n_err         = @n_err       
         ,  @c_errmsg      = @c_errmsg
         
         GOTO EXIT_SP    
      END CATCH
   END TRY

   BEGIN CATCH
      SET @n_continue = 3
      SET @c_ErrMsg = 'Wave Populate SO fail. (lsp_WAV_PopulateSO_Wrapper) ( SQLSvr MESSAGE=' + ERROR_MESSAGE() + ' ) '
      GOTO EXIT_SP
   END CATCH 
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_WAV_PopulateSO_Wrapper'
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