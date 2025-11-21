SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: lsp_WaveSplitOrder                                  */                                                                                  
/* Creation Date: 2019-04-05                                            */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-1794 - SPs for Wave Control Screens                    */
/*          - ( Split Order for Wave )                                  */
/*                                                                      */                                                                                  
/* Called By: SCE                                                       */                                                                                  
/*          :                                                           */                                                                                  
/* PVCS Version: 1.2                                                    */                                                                                  
/*                                                                      */                                                                                  
/* Version: 8.0                                                         */                                                                                  
/*                                                                      */                                                                                  
/* Data Modifications:                                                  */                                                                                  
/*                                                                      */                                                                                  
/* Updates:                                                             */                                                                                  
/* Date        Author   Ver.  Purposes                                  */  
/* 2021-02-10  mingle01 1.1   Add Big Outer Begin try/Catch              */
/*                            Execute Login if @c_UserName<>SUSER_SNAME()*/
/* 2023-03-17  Wan01    1.2   LFWM-4066-[CN] CartersSplit the not fullly*/
/*                            allocated Orders issue                    */
/************************************************************************/                                                                                  
CREATE   PROC [WM].[lsp_WaveSplitOrder]                                                                                                                     
      @c_WaveKey              NVARCHAR(10)
   ,  @b_Success              INT = 1           OUTPUT  
   ,  @n_err                  INT = 0           OUTPUT                                                                                                             
   ,  @c_ErrMsg               NVARCHAR(255)     OUTPUT   
   ,  @c_UserName             NVARCHAR(128)= ''  
   ,  @n_ErrGroupKey          INT          = 0  OUTPUT                                                                                                                          
AS  
BEGIN                                                                                                                                                        
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF       

   DECLARE  @n_StartTCnt         INT = @@TRANCOUNT  
         ,  @n_Continue          INT = 1

         ,  @n_Cnt               INT = 0

         --,  @c_SplitType         NVARCHAR(10)   = 'WAVE'        --(Wan01)

         ,  @c_Facility          NVARCHAR(5)    = ''
         ,  @c_Storerkey         NVARCHAR(15)   = ''

         ,  @c_Status            NVARCHAR(10)   = '0'
         ,  @c_FinalizeFlag      NVARCHAR(10)   = 'N'

         ,  @c_SchemaSP          NVARCHAR(10)   = ''
         ,  @c_SQL               NVARCHAR(1000) = ''
         ,  @c_SQLParms          NVARCHAR(1000) = ''

         ,  @c_TableName         NVARCHAR(50)   = 'ORDERS'
         ,  @c_SourceType        NVARCHAR(50)   = 'lsp_WaveSplitOrder'

         , @c_WaveSplitOrder_SP  NVARCHAR(30)   = ''

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

      SET @n_ErrGroupKey = ISNULL(@n_ErrGroupKey,0)

      IF OBJECT_ID('tempdb..#tORDERS','u') IS NOT NULL
      BEGIN
         DROP TABLE #tORDERS
      END 

      CREATE TABLE #tORDERS
         (  RowRef      INT            NOT NULL IDENTITY(1,1)  Primary Key
         ,  Wavekey     NVARCHAR(10)   NOT NULL DEFAULT ('')
         ,  Loadkey     NVARCHAR(10)   NOT NULL DEFAULT ('')
         ,  MBOLkey     NVARCHAR(10)   NOT NULL DEFAULT ('')
         ,  Orderkey    NVARCHAR(10)   NOT NULL DEFAULT ('')
         ,  OrderStatus NVARCHAR(10)   NOT NULL DEFAULT ('')
         ,  Facility    NVARCHAR(5)    NOT NULL DEFAULT ('')
         ,  Storerkey   NVARCHAR(15)   NOT NULL DEFAULT ('')
         )

      --IF @c_SplitType = 'WAVE'             --(Wan01)
      --BEGIN
         INSERT INTO #tORDERS ( Wavekey, Loadkey, MBOLKey, Orderkey, OrderStatus, Facility, Storerkey )
         SELECT WD.Wavekey
               ,Loadkey = ISNULL(OH.Loadkey,'')
               ,MBOLKey = ISNULL(OH.MBOLKey,'')
               ,OH.Orderkey
               ,OH.[Status]
               ,OH.Facility
               ,OH.Storerkey
         FROM WAVEDETAIL WD WITH (NOLOCK)
         JOIN ORDERS     OH WITH (NOLOCK) ON WD.Orderkey = OH.Orderkey
         WHERE WD.Wavekey = @c_Wavekey
      --END

      SET @c_Status = ''
      SELECT TOP 1 @c_Status = WH.[Status] 
      FROM #tORDERS T
      JOIN  WAVE WH WITH (NOLOCK) ON T.Wavekey = WH.Wavekey
      WHERE T.Wavekey <> ''
      ORDER BY WH.[Status] DESC

      IF @c_Status = '9'
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 557351
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Wave is closed. Splitting of Orders are not allowed. (lsp_WaveSplitOrder)' 

         EXEC [WM].[lsp_WriteError_List] 
               @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
            ,  @c_TableName   = @c_TableName
            ,  @c_SourceType  = @c_SourceType
            ,  @c_Refkey1     = @c_WaveKey
            ,  @c_Refkey2     = ''
            ,  @c_Refkey3     = ''
            ,  @c_WriteType   = 'ERROR' 
            ,  @n_err2        = @n_err 
            ,  @c_errmsg2     = @c_errmsg 
            ,  @b_Success     = @b_Success   OUTPUT 
            ,  @n_err         = @n_err       OUTPUT 
            ,  @c_errmsg      = @c_errmsg    OUTPUT
      END

      SET @c_Status = ''
      SELECT TOP 1 @c_Status = ISNULL(LP.[Status], '0')                          --(Wan01) 
      FROM #tORDERS T
      LEFT OUTER JOIN  LOADPLAN LP WITH (NOLOCK) ON T.Loadkey = LP.Loadkey       --(Wan01)
      --WHERE T.Loadkey <> ''                                                    --(Wan01)
      ORDER BY LP.[Status] --DESC                                                --(Wna01)   Do not Split if All shipped

      IF @c_Status = '9'
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 557352
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': All Loadplan are shipped. Splitting of Orders are not allowed. (lsp_WaveSplitOrder)' 

         EXEC [WM].[lsp_WriteError_List] 
               @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
            ,  @c_TableName   = @c_TableName
            ,  @c_SourceType  = @c_SourceType
            ,  @c_Refkey1     = @c_WaveKey
            ,  @c_Refkey2     = ''
            ,  @c_Refkey3     = ''
            ,  @c_WriteType   = 'ERROR' 
            ,  @n_err2        = @n_err 
            ,  @c_errmsg2     = @c_errmsg 
            ,  @b_Success     = @b_Success   OUTPUT 
            ,  @n_err         = @n_err       OUTPUT 
            ,  @c_errmsg      = @c_errmsg    OUTPUT
      END

      SET @c_Status = ''
      SET @c_FinalizeFlag = 'N'
      SELECT @c_Status = MIN(ISNULL(MH.[Status],'0'))                            --(Wan01)
            ,@c_FinalizeFlag = ISNULL(MAX(MH.FinalizeFlag),'N')         
      FROM #tORDERS T
      LEFT OUTER JOIN  MBOL MH WITH (NOLOCK) ON T.MBOLkey = MH.MBOLKey           --(Wan01)
      --WHERE T.MBOLkey <> ''                                                    --(Wan01)

      IF @c_Status = '9' --OR @c_FinalizeFlag = 'Y'                              --(Wan01) Do not Split if All shipped
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 557353
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': All Ship Ref. Unit are shipped. Splitting of Orders are not allowed. (lsp_WaveSplitOrder)' 

         EXEC [WM].[lsp_WriteError_List] 
               @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
            ,  @c_TableName   = @c_TableName
            ,  @c_SourceType  = @c_SourceType
            ,  @c_Refkey1     = @c_WaveKey
            ,  @c_Refkey2     = ''
            ,  @c_Refkey3     = ''
            ,  @c_WriteType   = 'ERROR' 
            ,  @n_err2        = @n_err 
            ,  @c_errmsg2     = @c_errmsg 
            ,  @b_Success     = @b_Success   OUTPUT 
            ,  @n_err         = @n_err       OUTPUT 
            ,  @c_errmsg      = @c_errmsg    OUTPUT

      END

      IF NOT EXISTS (SELECT 1 FROM #tORDERS)
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 557354
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': No detail Orders found.  (lsp_WaveSplitOrder)' 

         EXEC [WM].[lsp_WriteError_List] 
               @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
            ,  @c_TableName   = @c_TableName
            ,  @c_SourceType  = @c_SourceType
            ,  @c_Refkey1     = @c_WaveKey
            ,  @c_Refkey2     = ''
            ,  @c_Refkey3     = ''
            ,  @c_WriteType   = 'ERROR' 
            ,  @n_err2        = @n_err 
            ,  @c_errmsg2     = @c_errmsg 
            ,  @b_Success     = @b_Success   OUTPUT 
            ,  @n_err         = @n_err       OUTPUT 
            ,  @c_errmsg      = @c_errmsg    OUTPUT

      END

      SELECT TOP 1 
               @c_Facility = T.Facility
            ,  @c_Storerkey= T.Storerkey
      FROM #tORDERS T

      SET @c_WaveSplitOrder_SP = ''
      SELECT @c_WaveSplitOrder_SP  = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'WaveSplitOrder_SP')


      --Default to call lsp_SplitNotFullAllocOrder
      IF @c_WaveSplitOrder_SP IN ( '1', '0' )
      BEGIN
         SET @c_WaveSplitOrder_SP = 'isp_SplitWaveNotFullAllocOrder' --'lsp_SplitNotFullAllocOrder'
      END

      SET @n_Cnt = 0
      SELECT @n_Cnt = 1 
            ,@c_SchemaSP = SCHEMA_NAME(schema_id) 
      FROM SYS.OBJECTS WITH (NOLOCK) 
      WHERE [Type] = 'P' 
      AND   [Name] = @c_WaveSplitOrder_SP

      IF @n_Cnt = 0
      BEGIN
         SET @n_Err = 557355
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Invalid Stored Procedure name:' + @c_WaveSplitOrder_SP
                       + '. (lsp_WaveSplitOrder)' 
                       + '|' + @c_WaveSplitOrder_SP

         EXEC [WM].[lsp_WriteError_List] 
               @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
            ,  @c_TableName   = @c_TableName
            ,  @c_SourceType  = @c_SourceType
            ,  @c_Refkey1     = @c_WaveKey
            ,  @c_Refkey2     = ''
            ,  @c_Refkey3     = ''
            ,  @c_WriteType   = 'ERROR' 
            ,  @n_err2        = @n_err 
            ,  @c_errmsg2     = @c_errmsg 
            ,  @b_Success     = @b_Success   OUTPUT 
            ,  @n_err         = @n_err       OUTPUT 
            ,  @c_errmsg      = @c_errmsg    OUTPUT
      END

      IF @n_Continue = 3
      BEGIN
         GOTO EXIT_SP
      END

      SPLIT_ORDER:
      --SETUP Storerconfig 'WAVESPLITORDER_SP', svalue = isp_WTC_SplitOrdersBySkuThreshold if to 'Split by sku thres'
      BEGIN TRY
         SET @b_Success = 1
         SET @c_SQL = N'EXEC ' + @c_SchemaSP + '.' + @c_WaveSplitOrder_SP
                     + ' @c_WaveKey = @c_WaveKey' 
                     --+ ',@c_Loadkey = @c_Loadkey' 
                     --+ ',@c_MBOLKey = @c_MBOLKey' 
                     + ',@b_Success = @b_Success OUTPUT'
                     + ',@n_Err     = @n_Err     OUTPUT' 
                     + ',@c_ErrMsg  = @c_ErrMsg  OUTPUT' 

         SET @c_SQLParms = N'@c_WaveKey   NVARCHAR(10)' 
                        --+ ', @c_Loadkey    NVARCHAR(10)' 
                        --+ ', @c_MBOLKey    NVARCHAR(10)' 
                        + ', @b_Success    INT OUTPUT'
                        + ', @n_Err        INT OUTPUT' 
                        + ', @c_ErrMsg     NVARCHAR(255) OUTPUT'

         EXEC sp_ExecuteSQL  @c_SQL
                           , @c_SQLParms
                           , @c_WaveKey
                           --, @c_Loadkey  
                           --, @c_MBOLKey                     
                           , @b_Success   OUTPUT   
                           , @n_Err       OUTPUT
                           , @c_ErrMsg    OUTPUT


      END TRY

      BEGIN CATCH
         SET @n_Err = 557356
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Executing WaveSplitOrder_SP Stored Procedure. (lsp_WaveSplitOrder)' 
                        + '(' + @c_ErrMsg + ')'  
      END CATCH

      IF @b_Success = 0 OR @n_Err <> 0
      BEGIN
         SET @n_Err = 555655
         EXEC [WM].[lsp_WriteError_List] 
               @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
            ,  @c_TableName   = @c_TableName
            ,  @c_SourceType  = @c_SourceType
            ,  @c_Refkey1     = @c_WaveKey
            ,  @c_Refkey2     = ''
            ,  @c_Refkey3     = ''
            ,  @c_WriteType   = 'ERROR' 
            ,  @n_err2        = @n_err 
            ,  @c_errmsg2     = @c_errmsg 
            ,  @b_Success     = @b_Success   OUTPUT 
            ,  @n_err         = @n_err       OUTPUT 
            ,  @c_errmsg      = @c_errmsg    OUTPUT   
            
         GOTO EXIT_SP           
      END

      SET @c_errmsg = 'Wave Split Order process is done.'
      EXEC [WM].[lsp_WriteError_List] 
            @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
         ,  @c_TableName   = @c_TableName
         ,  @c_SourceType  = @c_SourceType
         ,  @c_Refkey1     = @c_WaveKey
         ,  @c_Refkey2     = ''
         ,  @c_Refkey3     = ''
         ,  @c_WriteType   = 'MESSAGE' 
         ,  @n_err2        = @n_err 
         ,  @c_errmsg2     = @c_errmsg 
         ,  @b_Success     = @b_Success   OUTPUT 
         ,  @n_err         = @n_err       OUTPUT 
         ,  @c_errmsg      = @c_errmsg    OUTPUT 
   END TRY
   
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
   --(mingle01) - END
EXIT_SP:
   IF (XACT_STATE()) = -1                                         --(Wan01)
   BEGIN
      SET @n_Continue=3
      ROLLBACK TRAN
   END  
 
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @n_StartTCnt = 0 AND @@TRANCOUNT > @n_StartTCnt         --(Wan01)
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_WaveSplitOrder'
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