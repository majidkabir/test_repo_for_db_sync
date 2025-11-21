SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: WM.lsp_WaveAllocationStatus_Wrapper                 */                                                                                  
/* Creation Date: 2022-02-18                                            */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-3280 - UATCNSCEUnable to allocate with status stuck on */
/*        : 'submitted'                                                 */
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
/* 2022-02-18  Wan01    1.0   Created.                                  */
/* 2022-02-18  Wan01    1.0   DevOps Combine Script.                    */
/************************************************************************/                                                                                  
CREATE PROC [WM].[lsp_WaveAllocationStatus_Wrapper]                                                                                                                     
      @c_Wavekey              NVARCHAR(250)  = '' 
   ,  @c_SortPreference       NVARCHAR(100)  = ''              -- Sort column + Sort type, If multiple Columns Sortig, seperate by ','
   ,  @b_Success              INT = 1              OUTPUT  
   ,  @n_err                  INT = 0              OUTPUT                                                                                                             
   ,  @c_ErrMsg               NVARCHAR(255)  = ''  OUTPUT 
   ,  @c_UserName             NVARCHAR(128)  = ''                                                                                                                         
AS  
BEGIN                                                                                                                                                        
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF       

   DECLARE  @n_StartTCnt                  INT = @@TRANCOUNT  
         ,  @n_Continue                   INT = 1
         
         ,  @c_Facility                   NVARCHAR(5)    = ''
         ,  @c_Storerkey                  NVARCHAR(15)   = ''
         ,  @c_IP                         NVARCHAR(20)   = ''  
         ,  @c_Port                       NVARCHAR(5)    = '' 
         ,  @c_DataStream                 NVARCHAR(10)   = ''  
         ,  @n_Priority                   INT            = 0

         ,  @c_SQL                        NVARCHAR(3000) = ''
         ,  @c_SQLParms                   NVARCHAR(3000) = ''

   IF OBJECT_ID('tempdb..#TMP_WaveAllocStatus','u') IS NULL  
   BEGIN                                                                                                                                      
      CREATE TABLE #TMP_WaveAllocStatus                                                                                                                                    
      (                                                                                                                                                           
         RowID          INT            NOT NULL IDENTITY(1,1)  PRIMARY KEY                 
      ,  Wavekey        NVARCHAR(10)   NOT NULL DEFAULT('')            
      ,  SendAllocCmd   NVARCHAR(255)  NOT NULL DEFAULT('')            
      ,  [Status]       NVARCHAR(10)   NOT NULL DEFAULT('0')             
      ,  StatusMsg      NVARCHAR(500)  NOT NULL DEFAULT('') 
      ,  AddWho         NVARCHAR(128)  NOT NULL DEFAULT('')       
      ,  EditWho        NVARCHAR(128)  NOT NULL DEFAULT('')  
      ,  EditDate       DATETIME       NOT NULL DEFAULT(GETDATE())           
      )   
   END 

   SET @b_Success = 1
   SET @n_Err     = 0
   
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

   BEGIN TRY
      SELECT TOP 1 
              @c_Facility = OH.Facility
            , @c_Storerkey= OH.Storerkey
      FROM WAVEDETAIL WD WITH (NOLOCK)
      JOIN ORDERS OH WITH (NOLOCK) ON WD.Orderkey = OH.Orderkey
      WHERE WD.Wavekey =  @c_Wavekey
      ORDER BY WD.Wavedetailkey

      SET @c_SortPreference = ISNULL(@c_SortPreference,'')
      IF @c_SortPreference = ''
      BEGIN
         SET @c_SortPreference = N' ORDER BY RowID ASC'
      END
      ELSE 
      BEGIN
         SET @c_SortPreference = N' ORDER BY ' +  @c_SortPreference
      END

      SELECT TOP 1                                             
               @c_IP              = qcfg.[IP]           --Service Box IP
            ,  @c_Port            = qcfg.[PORT]         --xx801: Backend Allocation, xx:please refer to country's used xx number.
            ,  @c_DataStream      = qcfg.DataStream     --BACKENDALC
            ,  @n_Priority        = qcfg.[Priority] 
      FROM  dbo.QCmd_TransmitlogConfig qcfg WITH (NOLOCK)  
      WHERE qcfg.TableName      = 'MANUALALLOC'
      AND   qcfg.[App_Name]     = 'WMS'  
      ORDER BY CASE WHEN qcfg.StorerKey = @c_Storerkey THEN 1          
                     WHEN qcfg.StorerKey = 'ALL' THEN 2 ELSE 3          
                     END                                                
            , qcfg.RowRefNo                                            
      
      INSERT INTO #TMP_WaveAllocStatus
         (
            Wavekey           
         ,  SendAllocCmd      
         ,  [Status]            
         ,  StatusMsg  
         ,  AddWho
         ,  EditWho      
         ,  EditDate
         )
      SELECT Wavekey = @c_Wavekey
            ,SendAllocCmd = tsqt.Cmd
            ,[Status] = ISNULL(tsqt.[Status],'0')
            ,StatusMsg = ISNULL(  CASE WHEN tsqt.Status = '0' THEN 'Submitted to QCommander'
                                       WHEN tsqt.Status = '0' AND tsqt.ErrMsg = '' THEN 'Processed by QCommander'
                                       ELSE tsqt.ErrMsg 
                                       END
                               , '')   
            ,tsqt.AddWho
            ,tsqt.EditWho
            ,tsqt.EditDate
            FROM dbo.TCPSocket_QueueTask AS tsqt  WITH (NOLOCK)
            WHERE tsqt.DataStream = @c_DataStream
            AND tsqt.TransmitLogKey = @c_Wavekey
            AND tsqt.Storerkey = @c_Storerkey
            AND tsqt.[IP] = @c_IP
            AND tsqt.[Port] = @c_PORT
            AND tsqt.[Priority] = @n_Priority
            AND tsqt.CmdType = 'SQL'
      UNION 
      SELECT Wavekey = @c_Wavekey
            ,SendAllocCmd = ISNULL(tsqtl.Cmd,'')
            ,[Status] = ISNULL(tsqtl.[Status],'0')
            ,StatusMsg = ISNULL(CASE WHEN tsqtl.Status = '0' THEN 'Submitted to QCommander'
                                     WHEN tsqtl.Status = '0' AND tsqtl.ErrMsg = '' THEN 'Processed by QCommander' 
                                     ELSE tsqtl.ErrMsg                               
                                     END
                                ,'')
            ,tsqtl.AddWho
            ,tsqtl.EditWho
            ,tsqtl.EditDate
      FROM dbo.TCPSocket_QueueTask_Log AS tsqtl WITH (NOLOCK)
      WHERE tsqtl.DataStream = @c_DataStream
      AND tsqtl.TransmitLogKey = @c_Wavekey
      AND tsqtl.Storerkey = @c_Storerkey
      AND tsqtl.[IP] = @c_IP
      AND tsqtl.[Port] = @c_PORT
      AND tsqtl.[Priority] = @n_Priority
      AND tsqtl.CmdType = 'SQL'
      ORDER BY EditDate DESC

      SET @c_SQL = N'SELECT Wavekey'
                 +', SendAllocCmd'
                 +', [Status]'  
                 +', StatusMsg'  
                 +', AddWho'                      
                 +', EditWho'     
                 +', EditDate'
                 +' FROM #TMP_WaveAllocStatus'
                 + @c_SortPreference

      EXEC (@c_SQL)

   END TRY
   
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH

EXIT_SP:
   IF OBJECT_ID('tempdb..#TMP_WaveAllocStatus','u') IS NOT NULL  
   BEGIN                                                                                                                                      
      DROP TABLE #TMP_WaveAllocStatus;                                                                                                                                  
   END 

IF (XACT_STATE()) = -1                                     
   BEGIN
      SET @n_Continue = 3
      ROLLBACK TRAN
   END 

   IF @n_Continue=3  -- Error Occured - Process And Return
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'WM.lsp_WaveAllocationStatus_Wrapper'
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